import Foundation

// MARK: - AuthService
// 封装所有认证相关的网络请求，供 ViewModel 调用。

final class AuthService {

    static let shared = AuthService()
    private init() {}

    private let client = APIClient.shared

    // MARK: - 登录

    func login(email: String, password: String) async throws -> LoginResponse {
        try await client.request(.login, body: LoginRequest(email: email, password: password))
    }

    // MARK: - 注册

    func register(email: String, password: String, name: String) async throws {
        try await client.requestVoid(
            .register,
            body: RegisterRequest(email: email, password: password, name: name)
        )
    }

    // MARK: - 登出

    func logout() async throws {
        try await client.requestVoid(.logout)
    }

    // MARK: - 刷新 Token

    func refresh() async throws -> RefreshResponse {
        try await client.request(.refresh)
    }
}
