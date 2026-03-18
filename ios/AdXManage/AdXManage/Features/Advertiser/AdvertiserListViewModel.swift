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

    // ── 报表指标 ───────────────────────────────────────────
    @Published var reportMetrics: [String: AdvertiserReportMetrics] = [:]
    @Published var totalMetrics: AdvertiserReportMetrics? = nil
    @Published var isLoadingMetrics = false

    // ── 日期筛选 ───────────────────────────────────────────
    @Published var selectedStartDate: Date = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date()))!
    @Published var selectedEndDate: Date   = Calendar.current.startOfDay(for: Date())

    struct SyncResult: Identifiable {
        let id = UUID()
        let response: SyncResponse
    }

    private let service       = AdvertiserService.shared
    private let statsService  = StatsService.shared
    private var page          = 1
    private let pageSize      = 20
    private var searchTask: Task<Void, Never>? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var startDateString: String { Self.dateFormatter.string(from: selectedStartDate) }
    var endDateString: String   { Self.dateFormatter.string(from: selectedEndDate) }

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
            await loadMetrics()
        } catch {
            self.error = errorMessage(error)
        }
        isLoading = false
    }

    // MARK: - 下拉刷新

    func refresh() async {
        page  = 1
        error = nil
        reportMetrics = [:]
        totalMetrics  = nil
        do {
            let (fetched, pagination) = try await fetch(page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
            await loadMetrics()
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

    // MARK: - 报表指标加载

    /// 拉取当前列表所有广告主的报表指标。
    /// 按平台分组后，每组发起一次 /stats/report 请求（服务端内部做批次拆分）。
    func loadMetrics() async {
        guard !items.isEmpty else { return }
        isLoadingMetrics = true

        // 按平台分组
        var byPlatform: [String: [String]] = [:]
        for item in items {
            byPlatform[item.platform, default: []].append(item.advertiserID)
        }

        var mergedMetrics: [String: AdvertiserReportMetrics] = [:]
        var combinedTotal: AdvertiserReportMetrics? = nil

        await withTaskGroup(of: StatsReportResponse?.self) { group in
            for (plt, ids) in byPlatform {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    do {
                        return try await self.statsService.advertiserReport(
                            platform: plt,
                            advertiserIDs: ids,
                            startDate: self.startDateString,
                            endDate: self.endDateString
                        )
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                guard let resp = result else { continue }
                for metric in resp.list {
                    mergedMetrics[metric.advertiserID] = metric
                }
                if let total = resp.totalMetrics {
                    if combinedTotal == nil {
                        combinedTotal = total
                    } else {
                        // 跨平台合并汇总
                        combinedTotal = mergeTotal(combinedTotal!, total)
                    }
                }
            }
        }

        reportMetrics = mergedMetrics
        totalMetrics  = combinedTotal
        isLoadingMetrics = false
    }

    // MARK: - 日期变更

    func onDateRangeChanged() {
        reportMetrics = [:]
        totalMetrics  = nil
        Task { await loadMetrics() }
    }

    // MARK: - 手动同步单个广告主

    func sync(advertiser: AdvertiserListItem) async {
        syncingID = advertiser.id
        defer { syncingID = nil }
        do {
            let resp = try await service.sync(id: advertiser.id)
            syncResult = SyncResult(response: resp)
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

    private func errorMessage(_ error: Error) -> String? {
        if error is CancellationError { return nil }
        if let e = error as? APIError { return e.errorDescription ?? error.localizedDescription }
        return error.localizedDescription
    }

    private func mergeTotal(_ a: AdvertiserReportMetrics, _ b: AdvertiserReportMetrics) -> AdvertiserReportMetrics {
        // 使用 zero 工厂方法避免重复初始化
        struct M {
            var advertiserID = "-"
            var spend = 0.0; var clicks = 0; var impressions = 0
            var conversion = 0; var costPerConversion = 0.0; var cpa = 0.0
            var currency = ""; var dailyBudget = 0.0
        }
        var m = M()
        m.spend       = a.spend + b.spend
        m.clicks      = a.clicks + b.clicks
        m.impressions = a.impressions + b.impressions
        m.conversion  = a.conversion + b.conversion
        m.dailyBudget = a.dailyBudget + b.dailyBudget
        // Encode/Decode to construct the Decodable struct
        let dict: [String: Any] = [
            "advertiser_id": m.advertiserID,
            "spend": m.spend, "clicks": m.clicks, "impressions": m.impressions,
            "conversion": m.conversion, "cost_per_conversion": m.costPerConversion,
            "cpa": m.cpa, "currency": m.currency, "daily_budget": m.dailyBudget
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let result = try? JSONDecoder().decode(AdvertiserReportMetrics.self, from: data) {
            return result
        }
        return a
    }
}
