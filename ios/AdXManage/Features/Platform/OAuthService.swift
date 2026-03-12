import Foundation
import AuthenticationServices

// MARK: - OAuthService
// 封装完整的 OAuth 授权流程：获取 URL → ASWebAuthenticationSession → 回传后端。

final class OAuthService: NSObject {

    static let shared = OAuthService()
    private override init() {}

    /// 自定义 URL Scheme，须在 Info.plist URL Types 中注册
    private let callbackScheme = "adxmanage"

    // ASWebAuthenticationSession 必须持有强引用，否则会被释放
    private var authSession: ASWebAuthenticationSession?

    private let client = APIClient.shared

    // MARK: - 完整授权流程

    /// 1. 向后端获取 OAuth URL
    /// 2. 用 ASWebAuthenticationSession 打开平台授权页
    /// 3. 提取 code + state，回传后端完成 token 交换 + 触发同步
    @MainActor
    func authorize(platform: Platform) async throws -> OAuthCallbackResponse {
        // Step 1: 获取 OAuth URL
        let urlResp: OAuthURLResponse = try await client.request(
            .oauthURL(platform: platform.rawValue)
        )
        guard let authURL = URL(string: urlResp.url) else {
            throw OAuthError.invalidCallbackURL
        }

        // Step 2: 打开平台授权页，等待回调
        let callbackURL = try await startWebAuthSession(url: authURL)

        // Step 3: 从回调 URL 解析 code + state
        guard let components  = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems  = components.queryItems,
              let code        = queryItems.first(where: { $0.name == "code"  })?.value,
              let state       = queryItems.first(where: { $0.name == "state" })?.value
        else {
            throw OAuthError.missingCodeOrState
        }

        // Step 4: 回传后端，触发 token 交换 + 后台数据同步
        return try await client.request(
            .oauthCallback(platform: platform.rawValue),
            body: OAuthCallbackRequest(code: code, state: state)
        )
    }

    // MARK: - 解绑授权

    func revoke(platform: Platform, tokenID: UInt64) async throws {
        try await client.requestVoid(.oauthRevoke(platform: platform.rawValue, tokenID: Int(tokenID)))
    }

    // MARK: - 私有：ASWebAuthenticationSession 包装

    @MainActor
    private func startWebAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.authSession = nil

                if let error = error as? ASWebAuthenticationSessionError {
                    if error.code == .canceledLogin {
                        continuation.resume(throwing: OAuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: OAuthError.sessionError(error))
                    }
                } else if let error {
                    continuation.resume(throwing: OAuthError.sessionError(error))
                } else if let url = callbackURL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: OAuthError.invalidCallbackURL)
                }
            }
            session.presentationContextProvider = self
            // false：使用 Safari 已登录的 cookie，让用户免登录直接授权
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            session.start()
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
