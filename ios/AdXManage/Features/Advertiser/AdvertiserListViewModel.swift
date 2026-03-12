import Foundation

// MARK: - AdvertiserListViewModel

@MainActor
final class AdvertiserListViewModel: ObservableObject {

    // ── 列表数据 ───────────────────────────────────────────
    @Published var items: [AdvertiserListItem]  = []
    @Published var isLoading    = false
    @Published var isLoadingMore = false
    @Published var hasMore      = false
    @Published var error: String? = nil

    // ── 筛选条件 ───────────────────────────────────────────
    @Published var searchText       = "" { didSet { scheduleSearch() } }
    @Published var platformFilter: Platform? = nil { didSet { Task { await refresh() } } }

    // ── 同步状态 ───────────────────────────────────────────
    @Published var syncingID: UInt64? = nil
    @Published var syncResult: SyncResult? = nil

    struct SyncResult: Identifiable {
        let id = UUID()
        let response: SyncResponse
    }

    private let service  = AdvertiserService.shared
    private var page     = 1
    private let pageSize = 20
    private var searchTask: Task<Void, Never>? = nil

    // MARK: - 初始加载

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error     = nil
        page      = 1
        do {
            let (fetched, pagination) = try await fetch(page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch {
            self.error = errorMessage(error)
        }
        isLoading = false
    }

    // MARK: - 下拉刷新

    func refresh() async {
        page  = 1
        error = nil
        do {
            let (fetched, pagination) = try await fetch(page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch {
            self.error = errorMessage(error)
        }
    }

    // MARK: - 分页加载

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let (fetched, pagination) = try await fetch(page: page)
            items  += fetched
            hasMore = pagination.hasMore
            page   += 1
        } catch {
            self.error = errorMessage(error)
        }
        isLoadingMore = false
    }

    // MARK: - 手动同步单个广告主

    func sync(advertiser: AdvertiserListItem) async {
        syncingID = advertiser.id
        defer { syncingID = nil }
        do {
            let resp = try await service.sync(id: advertiser.id)
            syncResult = SyncResult(response: resp)
            // 同步完成后刷新列表
            await refresh()
        } catch {
            self.error = errorMessage(error)
        }
    }

    // MARK: - OAuth 成功后刷新

    func onOAuthSuccess() async {
        await refresh()
    }

    // MARK: - 私有

    private func fetch(page: Int) async throws -> ([AdvertiserListItem], APIPagination) {
        try await service.list(
            platform: platformFilter?.rawValue,
            keyword:  searchText,
            page:     page,
            pageSize: pageSize
        )
    }

    /// 搜索框变化后 300 ms debounce
    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    private func errorMessage(_ error: Error) -> String {
        if let e = error as? APIError { return e.errorDescription ?? error.localizedDescription }
        return error.localizedDescription
    }
}
