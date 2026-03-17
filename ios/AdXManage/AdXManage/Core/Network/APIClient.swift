import Foundation

// MARK: - APIClient

/// 全局网络客户端，基于 async/await + URLSession。
/// 自动注入 JWT Bearer Token，401 时触发登出回调。
final class APIClient {

    static let shared = APIClient()

    // 通过 AppState 注入，避免循环依赖
    var onUnauthorized: (() -> Void)?

    private let baseURL: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        // 开发期直接指向本地后端；发布前替换为正式域名
        baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
            ?? "http://localhost:8080/api/v1"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)

        encoder = JSONEncoder()

        decoder = JSONDecoder()
        // Go 的 time.Time 序列化带微秒（如 2026-03-13T12:23:58.488703+08:00）
        // Swift 默认 .iso8601 不支持小数秒，需自定义解码策略
        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { dec in
            let str = try dec.singleValueContainer().decode(String.self)
            if let d = isoFull.date(from: str)  { return d }
            if let d = isoBasic.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(
                in: try dec.singleValueContainer(),
                debugDescription: "无法解析日期：\(str)")
        }
    }

    // MARK: - 标准请求（返回单条数据）

    /// 发起请求并解析 `APIResponse<T>.data`。
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: (any Encodable)? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> T {
        let req  = try buildRequest(endpoint, body: body, queryParams: queryParams)
        let data = try await perform(req)
        let resp = try decode(APIResponse<T>.self, from: data)
        guard resp.code == APICode.ok else {
            throw mapBusinessError(resp.code, resp.message)
        }
        guard let value = resp.data else {
            throw APIError.serverError("响应 data 为空")
        }
        return value
    }

    // MARK: - 分页请求（返回列表 + 分页信息）

    /// 发起分页请求，解析 `data` 数组与 `pagination`。
    func requestPage<T: Decodable>(
        _ endpoint: APIEndpoint,
        queryParams: [String: String]? = nil
    ) async throws -> (items: [T], pagination: APIPagination) {
        let req  = try buildRequest(endpoint, body: nil, queryParams: queryParams)
        let data = try await perform(req)
        let resp = try decode(APIPageResponse<T>.self, from: data)
        guard resp.code == APICode.ok else {
            throw mapBusinessError(resp.code, resp.message)
        }
        return (resp.data ?? [], resp.pagination)
    }

    // MARK: - 无响应体请求（只校验 code）

    func requestVoid(
        _ endpoint: APIEndpoint,
        body: (any Encodable)? = nil
    ) async throws {
        let req  = try buildRequest(endpoint, body: body)
        let data = try await perform(req)
        // 用空壳类型解析只为取 code
        struct Empty: Decodable {}
        let resp = try decode(APIResponse<Empty>.self, from: data)
        guard resp.code == APICode.ok else {
            throw mapBusinessError(resp.code, resp.message)
        }
    }

    // MARK: - 私有：构建 URLRequest

    private func buildRequest(
        _ endpoint: APIEndpoint,
        body: (any Encodable)?,
        queryParams: [String: String]? = nil
    ) throws -> URLRequest {
        var urlString = baseURL + endpoint.path
        if let params = queryParams, !params.isEmpty {
            var comps = URLComponents(string: urlString)
            comps?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            urlString = comps?.url?.absoluteString ?? urlString
        }
        guard let url = URL(string: urlString) else {
            throw APIError.serverError("无效 URL: \(urlString)")
        }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try encoder.encode(body)
        }
        return req
    }

    // MARK: - 私有：执行请求

    private func perform(_ req: URLRequest) async throws -> Data {
        #if DEBUG
        let method = req.httpMethod ?? "GET"
        let url    = req.url?.absoluteString ?? ""
        if let body = req.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
            print("➡️ \(method) \(url)\n   Body: \(bodyStr)")
        } else {
            print("➡️ \(method) \(url)")
        }
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlErr as URLError where urlErr.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.networkError(error)
        }

        #if DEBUG
        let status  = (response as? HTTPURLResponse)?.statusCode ?? 0
        let respStr = String(data: data, encoding: .utf8) ?? "<binary>"
        print("⬅️ \(status) \(url)\n   Body: \(respStr)")
        #endif

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            onUnauthorized?()
            throw APIError.unauthorized
        }
        return data
    }

    // MARK: - 私有：解码

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - 私有：业务错误映射

    private func mapBusinessError(_ code: Int, _ message: String) -> APIError {
        switch code {
        case APICode.unauthorized:   return .unauthorized
        case APICode.tokenExpired:   return .oauthTokenExpired
        case APICode.forbidden:      return .forbidden
        case APICode.invalidParam:   return .invalidParam(message)
        case APICode.platformError:  return .platformError(message)
        default:                     return .businessError(code: code, message: message)
        }
    }
}
