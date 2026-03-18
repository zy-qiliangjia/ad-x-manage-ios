import SwiftUI

// MARK: - AdGroupListViewModel

@MainActor
final class AdGroupListViewModel: ObservableObject {

    @Published var items: [AdGroupItem]  = []
    @Published var isLoading             = false
    @Published var isLoadingMore         = false
    @Published var hasMore               = false
    @Published var error: String?        = nil

    @Published var budgetTarget: AdGroupItem?      = nil
    @Published var statusConfirmTarget: AdGroupItem? = nil
    @Published var updatingStatusID: UInt64?       = nil

    // 汇总统计
    @Published var dateFilter: DateRangeFilter = .last7Days {
        didSet {
            metricsLoadedKey = nil // 日期变化时清除指标缓存
            Task { await loadSummary() }
            Task { await loadAdGroupMetrics() }
        }
    }
    @Published var summary: StatsSummary? = nil
    @Published var summaryLoading        = false

    // 逐广告组报表指标
    @Published var adGroupMetrics: [String: AdGroupReportMetrics] = [:]
    @Published var isLoadingMetrics = false

    var lastUpdatedLabel: String? { summary?.updatedTimeLabel }

    private let advertiserID: UInt64
    private let campaignID: UInt64
    private let service      = AdDetailService.shared
    private let statsService = StatsService.shared
    private var page     = 1
    private let pageSize = 20

    // 30分钟本地指标缓存
    private var metricsLoadedKey: String? = nil
    private var metricsLoadedAt: Date?    = nil
    private let metricsCacheTTL: TimeInterval = 30 * 60

    init(advertiserID: UInt64, campaignID: UInt64 = 0) {
        self.advertiserID = advertiserID
        self.campaignID   = campaignID
    }

    private var summaryScope: (scope: String, id: UInt64) {
        campaignID > 0 ? ("campaign", campaignID) : ("advertiser", advertiserID)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; page = 1
        do {
            let (fetched, pagination) = try await service.adGroups(advertiserID: advertiserID, campaignID: campaignID, page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = message(error) }
        isLoading = false
        await loadSummary()
        await loadAdGroupMetrics()
    }

    func refresh() async {
        page = 1; error = nil
        do {
            let (fetched, pagination) = try await service.adGroups(advertiserID: advertiserID, campaignID: campaignID, page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = message(error) }
        await loadSummary()
        metricsLoadedKey = nil // 刷新时强制重新拉取
        await loadAdGroupMetrics()
    }

    func loadAdGroupMetrics() async {
        guard !items.isEmpty else { return }

        let r = dateFilter.dateRange
        let cacheKey = "\(advertiserID)-\(r.from)-\(r.to)"

        // 30分钟内已缓存则跳过
        if let key = metricsLoadedKey, let loadedAt = metricsLoadedAt,
           key == cacheKey, Date().timeIntervalSince(loadedAt) < metricsCacheTTL {
            return
        }

        isLoadingMetrics = true
        let ids = items.map { $0.adgroupID }
        if let resp = try? await statsService.adGroupReport(
            advertiserDBID: advertiserID,
            adGroupIDs: ids,
            startDate: r.from,
            endDate: r.to
        ) {
            var map: [String: AdGroupReportMetrics] = [:]
            for m in resp.list { map[m.adgroupID] = m }
            adGroupMetrics = map
            metricsLoadedKey = cacheKey
            metricsLoadedAt  = Date()
        }
        isLoadingMetrics = false
    }

    func loadSummary() async {
        summaryLoading = true
        let r = dateFilter.dateRange
        let s = summaryScope
        summary = try? await statsService.summary(scope: s.scope, scopeID: s.id,
                                                  dateFrom: r.from, dateTo: r.to)
        summaryLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let (fetched, pagination) = try await service.adGroups(advertiserID: advertiserID, campaignID: campaignID, page: page)
            items  += fetched
            hasMore = pagination.hasMore
            page   += 1
        } catch { self.error = message(error) }
        isLoadingMore = false
    }

    func updateBudget(item: AdGroupItem, budget: Double) async {
        do {
            try await service.updateAdGroupBudget(id: item.id, budget: budget)
            await refresh()
        } catch { self.error = message(error) }
    }

    func updateStatus(item: AdGroupItem, action: String) async {
        updatingStatusID = item.id
        defer { updatingStatusID = nil }
        do {
            try await service.updateAdGroupStatus(id: item.id, action: action)
            await refresh()
        } catch { self.error = message(error) }
    }

    private func message(_ e: Error) -> String? {
        if e is CancellationError { return nil }
        return (e as? APIError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - AdGroupListView

struct AdGroupListView: View {

    let advertiser: AdvertiserListItem
    @StateObject private var vm: AdGroupListViewModel

    init(advertiser: AdvertiserListItem, campaignID: UInt64 = 0) {
        self.advertiser = advertiser
        _vm = StateObject(wrappedValue: AdGroupListViewModel(advertiserID: advertiser.id, campaignID: campaignID))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.items.isEmpty && !vm.isLoading {
                emptyView("暂无广告组")
            } else {
                list
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .confirmationDialog(
            statusDialogTitle,
            isPresented: Binding(
                get: { vm.statusConfirmTarget != nil },
                set: { if !$0 { vm.statusConfirmTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = vm.statusConfirmTarget {
                let isPause = target.status.isAdActive
                Button(isPause ? "暂停" : "开启",
                       role: isPause ? .destructive : nil) {
                    vm.statusConfirmTarget = nil
                    Task { await vm.updateStatus(item: target, action: isPause ? "pause" : "enable") }
                }
                Button("取消", role: .cancel) { vm.statusConfirmTarget = nil }
            }
        } message: {
            if let target = vm.statusConfirmTarget {
                Text(target.adgroupName)
            }
        }
        .task { await vm.load() }
    }

    private var list: some View {
        List {
            ForEach(vm.items) { item in
                AdGroupRow(item: item, isUpdatingStatus: vm.updatingStatusID == item.id)
                    .swipeActions(edge: .leading) {
                        Button { vm.budgetTarget = item } label: {
                            Label("改预算", systemImage: "pencil.circle.fill")
                        }.tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button { vm.statusConfirmTarget = item } label: {
                            Label(
                                item.status.isAdActive ? "暂停" : "开启",
                                systemImage: item.status.isAdActive ? "pause.circle" : "play.circle"
                            )
                        }
                        .tint(item.status.isAdActive ? .orange : .green)
                    }
                    .onAppear {
                        if item.id == vm.items.last?.id { Task { await vm.loadMore() } }
                    }
            }
            if vm.isLoadingMore { loadingMoreRow }
        }
        .listStyle(.plain)
        .refreshable { await vm.refresh() }
        .sheet(item: $vm.budgetTarget) { item in
            BudgetEditSheet(
                itemName:      item.adgroupName,
                currentBudget: item.budget,
                budgetMode:    item.budgetMode
            ) { newBudget in
                await vm.updateBudget(item: item, budget: newBudget)
            }
        }
    }

    // MARK: - 确认弹窗标题

    private var statusDialogTitle: String {
        guard let target = vm.statusConfirmTarget else { return "" }
        return target.status.isAdActive ? "确认暂停广告组？" : "确认开启广告组？"
    }
}

// MARK: - AdGroupRow

struct AdGroupRow: View {
    let item: AdGroupItem
    let isUpdatingStatus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.adgroupName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if isUpdatingStatus { ProgressView().scaleEffect(0.7) }
                else { StatusBadge(status: item.status) }
            }
            HStack(spacing: 16) {
                budgetView
                spendView
                if item.bidPrice > 0 { bidView }
            }
        }
        .padding(.vertical, 4)
    }

    private var budgetView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.budgetMode.budgetModeLabel).font(.caption2).foregroundStyle(.tertiary)
            Text(item.budgetMode == "BUDGET_MODE_INFINITE"
                 ? "不限" : item.budget.formatted(.number.precision(.fractionLength(2))))
                .font(.caption.weight(.medium))
        }
    }

    private var spendView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("消耗").font(.caption2).foregroundStyle(.tertiary)
            Text(item.spend.formatted(.number.precision(.fractionLength(2)))).font(.caption.weight(.medium))
        }
    }

    private var bidView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.bidType.isEmpty ? "出价" : item.bidType).font(.caption2).foregroundStyle(.tertiary)
            Text(item.bidPrice.formatted(.number.precision(.fractionLength(4)))).font(.caption.weight(.medium))
        }
    }
}
