import SwiftUI

// MARK: - AdListViewModel

@MainActor
final class AdListViewModel: ObservableObject {

    @Published var items: [AdItem]  = []
    @Published var isLoading        = false
    @Published var isLoadingMore    = false
    @Published var hasMore          = false
    @Published var error: String?   = nil

    @Published var statusConfirmTarget: AdItem?  = nil
    @Published var updatingStatusID: UInt64?     = nil

    @Published var searchText = "" { didSet { scheduleSearch() } }

    // 汇总统计
    @Published var dateFilter: DateRangeFilter = .last7Days {
        didSet {
            metricsLoadedKey = nil
            Task { await loadSummary() }
            Task { await loadAdMetrics() }
        }
    }
    @Published var summary: StatsSummary? = nil
    @Published var summaryLoading        = false

    // 逐广告报表指标
    @Published var adMetrics: [String: AdReportMetrics] = [:]
    @Published var isLoadingMetrics = false

    var lastUpdatedLabel: String? { summary?.updatedTimeLabel }

    let adgroupID: UInt64
    private let advertiserID: UInt64
    private let service      = AdDetailService.shared
    private let statsService = StatsService.shared
    private var page     = 1
    private let pageSize = 20
    private var searchTask: Task<Void, Never>? = nil

    // 30分钟本地指标缓存
    private var metricsLoadedKey: String? = nil
    private var metricsLoadedAt: Date?    = nil
    private let metricsCacheTTL: TimeInterval = 30 * 60

    init(advertiserID: UInt64, adgroupID: UInt64 = 0) {
        self.advertiserID = advertiserID
        self.adgroupID    = adgroupID
    }

    private var summaryScope: (scope: String, id: UInt64) {
        adgroupID > 0 ? ("adgroup", adgroupID) : ("advertiser", advertiserID)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; page = 1
        do {
            let (fetched, pagination) = try await service.ads(
                advertiserID: advertiserID, adgroupID: adgroupID, keyword: searchText, page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = message(error) }
        isLoading = false
        await loadSummary()
        await loadAdMetrics()
    }

    func refresh() async {
        page = 1; error = nil
        do {
            let (fetched, pagination) = try await service.ads(
                advertiserID: advertiserID, adgroupID: adgroupID, keyword: searchText, page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = message(error) }
        await loadSummary()
        metricsLoadedKey = nil
        await loadAdMetrics()
    }

    func loadAdMetrics() async {
        guard !items.isEmpty else { return }

        let r = dateFilter.dateRange
        let cacheKey = "\(advertiserID)-\(adgroupID)-\(r.from)-\(r.to)"

        // 30分钟内已缓存则跳过
        if let key = metricsLoadedKey, let loadedAt = metricsLoadedAt,
           key == cacheKey, Date().timeIntervalSince(loadedAt) < metricsCacheTTL {
            return
        }

        isLoadingMetrics = true
        let ids = items.map { $0.adID }
        if let resp = try? await statsService.adReport(
            advertiserDBID: advertiserID,
            adIDs: ids,
            startDate: r.from,
            endDate: r.to
        ) {
            var map: [String: AdReportMetrics] = [:]
            for m in resp.list { map[m.adID] = m }
            adMetrics        = map
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
            let (fetched, pagination) = try await service.ads(
                advertiserID: advertiserID, adgroupID: adgroupID, keyword: searchText, page: page)
            items  += fetched
            hasMore = pagination.hasMore
            page   += 1
        } catch { self.error = message(error) }
        isLoadingMore = false
        metricsLoadedKey = nil
        await loadAdMetrics()
    }

    func updateStatus(item: AdItem, action: String) async {
        updatingStatusID = item.id
        defer { updatingStatusID = nil }
        do {
            try await service.updateAdStatus(id: item.id, action: action)
            await refresh()
        } catch { self.error = message(error) }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    private func message(_ e: Error) -> String? {
        if e is CancellationError { return nil }
        return (e as? APIError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - AdListView

struct AdListView: View {

    let advertiser: AdvertiserListItem
    @StateObject private var vm: AdListViewModel

    init(advertiser: AdvertiserListItem, adgroupID: UInt64 = 0) {
        self.advertiser = advertiser
        _vm = StateObject(wrappedValue: AdListViewModel(advertiserID: advertiser.id, adgroupID: adgroupID))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 汇总卡片
            AdsSummaryCardView(
                scopeLabel:       vm.adgroupID > 0 ? "广告" : advertiser.advertiserName,
                spend:            vm.summary?.spend        ?? 0,
                clicks:           vm.summary?.clicks       ?? 0,
                impressions:      vm.summary?.impressions  ?? 0,
                conversions:      vm.summary?.conversions  ?? 0,
                dateFilter:       Binding(get: { vm.dateFilter }, set: { vm.dateFilter = $0 }),
                isLoadingSummary: vm.summaryLoading
            )
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.top, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.sm)

            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty && !vm.isLoading {
                    emptyView(vm.searchText.isEmpty ? "暂无广告" : "没有匹配的广告")
                } else {
                    list
                }
            }
        }
        .background(AppTheme.Colors.background)
        .searchable(text: $vm.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索广告 ID 或名称")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.summaryLoading || vm.isLoadingMetrics {
                    ProgressView().scaleEffect(0.7)
                } else if let label = vm.lastUpdatedLabel {
                    Text("更新于 \(label)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
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
                Text(target.adName)
            }
        }
        .task { await vm.load() }
    }

    private var list: some View {
        List {
            ForEach(vm.items) { item in
                AdRow(item: item,
                      metrics: vm.adMetrics[item.adID],
                      isUpdatingStatus: vm.updatingStatusID == item.id) {
                    vm.statusConfirmTarget = item
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
    }

    private var statusDialogTitle: String {
        guard let target = vm.statusConfirmTarget else { return "" }
        return target.status.isAdActive ? "确认暂停广告？" : "确认开启广告？"
    }
}

// MARK: - AdRow

struct AdRow: View {
    let item: AdItem
    var metrics: AdReportMetrics?     = nil
    var isUpdatingStatus: Bool        = false
    var onToggleStatus: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.adName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if isUpdatingStatus { ProgressView().scaleEffect(0.7) }
                else { StatusBadge(status: item.status) }
            }
            HStack(spacing: 6) {
                if !item.adgroupName.isEmpty {
                    Label(item.adgroupName, systemImage: "rectangle.stack")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            HStack(spacing: 12) {
                metricView(label: "消耗",  value: (metrics?.spend ?? 0).formatted(.number.precision(.fractionLength(2))))
                metricView(label: "点击",  value: "\(metrics?.clicks ?? 0)")
                metricView(label: "展示",  value: "\(metrics?.impressions ?? 0)")
                metricView(label: "转化",  value: "\(metrics?.conversion ?? 0)")
                metricView(label: "CPA",   value: cpaText)
                Spacer()
                toggleButton
            }
            Text(item.adID)
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var cpaText: String {
        guard let m = metrics, m.cpa > 0 else { return "--" }
        return m.cpa.formatted(.number.precision(.fractionLength(2)))
    }

    @ViewBuilder
    private var toggleButton: some View {
        if let action = onToggleStatus {
            Button(action: action) {
                Label(
                    item.status.isAdActive ? "暂停" : "开启",
                    systemImage: item.status.isAdActive ? "pause.circle" : "play.circle"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(item.status.isAdActive ? .orange : .green)
            }
            .buttonStyle(.plain)
        }
    }

    private func metricView(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.tertiary)
            Text(value).font(.caption.weight(.medium))
        }
    }
}
