import Foundation

// MARK: - OAuthViewModel

@MainActor
final class OAuthViewModel: ObservableObject {

    // ── 状态机 ─────────────────────────────────────────────
    enum Phase {
        case idle
        case authorizing(platform: Platform)   // 正在进行 OAuth 会话
        case processing(platform: Platform)    // 正在等待后端处理
        case success(OAuthCallbackResponse)
        case failure(message: String, platform: Platform?)
    }

    @Published var phase: Phase = .idle
    @Published var isPresented = false           // 控制 OAuthProgressView sheet

    private let service = OAuthService.shared

    // MARK: - 发起授权

    func authorize(platform: Platform) {
        isPresented = true
        Task { await run(platform: platform) }
    }

    // MARK: - 重试

    func retry(platform: Platform) {
        Task { await run(platform: platform) }
    }

    // MARK: - 关闭（外部调用，如成功后导航完成）

    func dismiss() {
        phase = .idle
        isPresented = false
    }

    // MARK: - 私有

    private func run(platform: Platform) async {
        phase = .authorizing(platform: platform)
        do {
            // 获取 URL + 打开 ASWebAuthenticationSession
            // 一旦用户在浏览器中完成授权，session 回调后切换到 processing
            let result = try await withPhaseSwitch(to: .processing(platform: platform)) {
                try await self.service.authorize(platform: platform)
            }
            phase = .success(result)
        } catch let err as OAuthError {
            phase = .failure(message: err.errorDescription ?? "授权失败", platform: platform)
        } catch let err as APIError {
            phase = .failure(message: err.errorDescription ?? "请求失败", platform: platform)
        } catch {
            phase = .failure(message: error.localizedDescription, platform: platform)
        }
    }

    /// 在 `action` 开始执行后，将 phase 切换为 `next`（用于 authorizing → processing 时机）
    /// 注：ASWebAuthenticationSession 本身是异步的，用户在浏览器授权期间
    ///     phase 保持 authorizing；浏览器关闭后 session 回调，此处才切换为 processing。
    private func withPhaseSwitch<T>(
        to next: Phase,
        _ action: @escaping () async throws -> T
    ) async throws -> T {
        // 启动一个并发任务：等 authSession 触发回调后更新 phase
        // 实际上，`authorize` 在 session 完成后才继续，因此在 action 返回前
        // 我们无法精确判断"浏览器已关闭"的时机。
        // 简化处理：session 完成（code 回来）= 进入 processing 阶段。
        let result = try await action()
        phase = next
        return result
    }
}
