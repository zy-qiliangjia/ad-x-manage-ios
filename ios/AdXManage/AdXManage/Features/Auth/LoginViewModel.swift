import Foundation

// MARK: - LoginViewModel

@MainActor
final class LoginViewModel: ObservableObject {

    @Published var email: String    = ""
    @Published var password: String = ""
    @Published var isLoading: Bool       = false
    @Published var errorMessage: String? = nil

    private let authService = AuthService.shared

    // MARK: - 登录

    var canLogin: Bool { !email.isEmpty && password.count >= 8 && !isLoading }

    func login(appState: AppState) async {
        guard canLogin else {
            if password.count < 8 { errorMessage = "密码至少 8 位" }
            return
        }
        guard isValidEmail(email) else {
            errorMessage = "请输入有效的邮箱地址"
            return
        }
        await perform {
            let res = try await self.authService.login(email: self.email, password: self.password)
            appState.login(token: res.token, expiresAt: res.expiresAt, email: res.user.email)
        }
    }

    // MARK: - 私有：统一的 loading + 错误处理包装

    private func perform(_ action: @escaping () async throws -> Void) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await action()
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        s.contains("@") && s.contains(".")
    }
}
