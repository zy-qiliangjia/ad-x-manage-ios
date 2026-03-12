import Foundation

// MARK: - LoginViewModel

@MainActor
final class LoginViewModel: ObservableObject {

    // ── 登录表单 ───────────────────────────────────────────
    @Published var email: String    = ""
    @Published var password: String = ""

    // ── 注册表单 ───────────────────────────────────────────
    @Published var regName: String            = ""
    @Published var regEmail: String           = ""
    @Published var regPassword: String        = ""
    @Published var regPasswordConfirm: String = ""

    // ── 状态 ───────────────────────────────────────────────
    @Published var isLoading: Bool      = false
    @Published var errorMessage: String? = nil
    @Published var showRegister: Bool   = false  // 控制注册 Sheet

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

    // MARK: - 注册

    var canRegister: Bool {
        !regName.isEmpty &&
        isValidEmail(regEmail) &&
        regPassword.count >= 8 &&
        regPassword == regPasswordConfirm &&
        !isLoading
    }

    var registerPasswordMismatch: Bool {
        !regPasswordConfirm.isEmpty && regPassword != regPasswordConfirm
    }

    func register(appState: AppState) async {
        guard canRegister else {
            if regName.isEmpty            { errorMessage = "请输入昵称" }
            else if !isValidEmail(regEmail) { errorMessage = "请输入有效的邮箱地址" }
            else if regPassword.count < 8  { errorMessage = "密码至少 8 位" }
            else if regPassword != regPasswordConfirm { errorMessage = "两次密码不一致" }
            return
        }
        await perform {
            try await self.authService.register(
                email: self.regEmail,
                password: self.regPassword,
                name: self.regName
            )
            // 注册成功后自动登录
            let res = try await self.authService.login(
                email: self.regEmail,
                password: self.regPassword
            )
            appState.login(token: res.token, expiresAt: res.expiresAt, email: res.user.email)
            self.showRegister = false
        }
    }

    // MARK: - 私有：统一的 loading + 错误处理包装

    private func perform(_ action: @escaping () async throws -> Void) async {
        isLoading     = true
        errorMessage  = nil
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
