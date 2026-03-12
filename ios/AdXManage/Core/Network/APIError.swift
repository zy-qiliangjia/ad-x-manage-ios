import Foundation

// MARK: - 业务错误码（对应后端 response 包常量）

enum APICode {
    static let ok            = 0
    static let unauthorized  = 1001
    static let invalidParam  = 1002
    static let platformError = 1003
    static let forbidden     = 1004
    static let tokenExpired  = 1005  // OAuth token 失效，需重新授权
    static let serverError   = 5000
}

// MARK: - 客户端错误类型

enum APIError: Error, LocalizedError {
    /// JWT 未登录或过期，跳转登录页
    case unauthorized
    /// OAuth 平台 Token 失效，需重新授权
    case oauthTokenExpired
    /// 无权限操作
    case forbidden
    /// 参数校验失败
    case invalidParam(String)
    /// 平台 API 调用失败
    case platformError(String)
    /// 服务器内部错误
    case serverError(String)
    /// 网络层错误（无网络、超时等）
    case networkError(Error)
    /// JSON 解码失败
    case decodingError(Error)
    /// 其他业务错误
    case businessError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:                    return "请先登录"
        case .oauthTokenExpired:               return "平台授权已失效，请重新授权"
        case .forbidden:                       return "无权限执行此操作"
        case .invalidParam(let msg):           return msg
        case .platformError(let msg):          return "平台错误：\(msg)"
        case .serverError(let msg):            return "服务器错误：\(msg)"
        case .networkError(let err):           return "网络错误：\(err.localizedDescription)"
        case .decodingError(let err):          return "数据解析失败：\(err.localizedDescription)"
        case .businessError(_, let msg):       return msg
        }
    }
}
