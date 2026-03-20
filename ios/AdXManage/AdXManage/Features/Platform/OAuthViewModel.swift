import Foundation

// MARK: - OAuthViewModel

@MainActor
final class OAuthViewModel: ObservableObject {

    // ── 状态机 ─────────────────────────────────────────────
    enum Phase {
        case idle
        case authorizing(platform: Platform)        // 正在进行 OAuth 会话
        case processing(platform: Platform)         // 正在等待后端处理
        case selecting(OAuthCallbackResponse)       // 等待用户选择广告主
        case confirming                             // 正在提交选择
        case success(OAuthConfirmResponse)          // 全部完成
        case failure(message: String, platform: Platform?)
    }

    @Published var phase: Phase = .idle
    @Published var isPresented = false              // 控制 OAuthProgressView sheet
    @Published var selectedIDs: Set<String> = []   // 用户勾选的广告主 ID

    private let service = OAuthService.shared

    // MARK: - 发起授权

    func authorize(platform: Platform) {
        isPresented = true
        Task { await run(platform: platform) }
    }

    // MARK: - 重试

    func retry(platform: Platform) {
        selectedIDs = []
        Task { await run(platform: platform) }
    }

    // MARK: - 选择/取消广告主（仅限新广告主，已存库的不可操作）

    func toggleSelection(_ advertiserID: String, resp: OAuthCallbackResponse) {
        if selectedIDs.contains(advertiserID) {
            selectedIDs.remove(advertiserID)
        } else {
            // 已选数不超过剩余额度才允许新增
            if selectedIDs.count < resp.remaining {
                selectedIDs.insert(advertiserID)
            }
        }
    }

    // MARK: - 确认提交选择

    func confirm(platform: Platform, resp: OAuthCallbackResponse) {
        Task { await runConfirm(platform: platform, resp: resp) }
    }

    // MARK: - 关闭（外部调用，如成功后导航完成）

    func dismiss() {
        phase = .idle
        isPresented = false
        selectedIDs = []
    }

    // MARK: - 私有

    private func run(platform: Platform) async {
        phase = .authorizing(platform: platform)
        do {
            let result = try await withPhaseSwitch(to: .processing(platform: platform)) {
                try await self.service.authorize(platform: platform)
            }
            selectedIDs = []
            phase = .selecting(result)
        } catch let err as OAuthError {
            phase = .failure(message: err.errorDescription ?? "授权失败", platform: platform)
        } catch let err as APIError {
            phase = .failure(message: err.errorDescription ?? "请求失败", platform: platform)
        } catch {
            phase = .failure(message: error.localizedDescription, platform: platform)
        }
    }

    private func runConfirm(platform: Platform, resp: OAuthCallbackResponse) async {
        phase = .confirming
        do {
            let result = try await service.confirm(
                platform: platform,
                tokenID: resp.tokenID,
                advertiserIDs: Array(selectedIDs)
            )
            phase = .success(result)
        } catch let err as APIError {
            phase = .failure(message: err.errorDescription ?? "提交失败", platform: platform)
        } catch {
            phase = .failure(message: error.localizedDescription, platform: platform)
        }
    }

    /// 在 `action` 开始执行后，将 phase 切换为 `next`（用于 authorizing → processing 时机）
    private func withPhaseSwitch<T>(
        to next: Phase,
        _ action: @escaping () async throws -> T
    ) async throws -> T {
        let result = try await action()
        phase = next
        return result
    }
}
