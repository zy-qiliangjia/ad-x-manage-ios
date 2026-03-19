import Foundation

// MARK: - AppState
// 全局认证状态，注入到 SwiftUI 环境中。

@MainActor
final class AppState: ObservableObject {

    @Published var isLoggedIn: Bool  = false
    @Published var userEmail: String = ""
    @Published var contactConfig: AppConfig? = nil

    init() {
        isLoggedIn = KeychainManager.shared.isLoggedIn
        userEmail  = KeychainManager.shared.loadEmail() ?? ""

        // 注册 JWT 401 时的自动登出回调
        APIClient.shared.onUnauthorized = { [weak self] in
            Task { @MainActor in self?.logout() }
        }

        // 启动时拉取服务端配置（客服联系方式等）
        Task { await fetchConfig() }

        // 启动时检查 Token 是否即将过期，自动续签
        if isLoggedIn {
            Task { await refreshTokenIfNeeded() }
        }
    }

    // MARK: - 登录成功后调用

    func login(token: String, expiresAt: Date, email: String) {
        KeychainManager.shared.saveToken(token, expiresAt: expiresAt, email: email)
        userEmail  = email
        isLoggedIn = true
    }

    // MARK: - 登出（本地清理 + 可选通知后端）

    func logout() {
        KeychainManager.shared.deleteToken()
        userEmail  = ""
        isLoggedIn = false
    }

    // MARK: - 自动续签

    /// Token 有效期不足 10 分钟时自动刷新，失败则强制登出。
    func refreshTokenIfNeeded() async {
        guard let expiresAt = KeychainManager.shared.tokenExpiresAt() else {
            logout()
            return
        }
        // 距离过期还有超过 10 分钟，无需刷新
        guard expiresAt.timeIntervalSinceNow < 600 else { return }

        do {
            let res   = try await AuthService.shared.refresh()
            let email = KeychainManager.shared.loadEmail() ?? userEmail
            login(token: res.token, expiresAt: res.expiresAt, email: email)
        } catch {
            // 刷新失败（token 已过期），跳回登录页
            logout()
        }
    }

    // MARK: - 拉取服务端配置

    private func fetchConfig() async {
        do {
            contactConfig = try await APIClient.shared.request(.appConfig)
        } catch {
            // 网络不可达时静默失败，弹窗内联系方式按钮不可点击
        }
    }
}
