import SwiftUI

// MARK: - CampaignListViewModel

@MainActor
final class CampaignListViewModel: ObservableObject {

    @Published var items: [CampaignItem]  = []
    @Published var isLoading              = false
    @Published var isLoadingMore          = false
    @Published var hasMore                = false
    @Published var error: String?         = nil

    // I7：预算编辑 Sheet
    @Published var budgetTarget: CampaignItem?   = nil
    // I7：状态切换确认弹窗
    @Published var statusConfirmTarget: CampaignItem? = nil
    // 正在更新状态的行（显示 spinner）
    @Published var updatingStatusID: UInt64? = nil

    // 汇总统计
    @Published var dateFilter: DateRangeFilter = .last7Days {
        didSet {
            metricsLoadedKey = nil // 日期变化时清除指标缓存
            Task { await loadSummary() }
            Task { await loadCampaignMetrics() }
        }
    }
    @Published var summary: StatsSummary? = nil
    @Published var summaryLoading        = false

    // 逐推广系列报表指标
    @Published var campaignMetrics: [String: CampaignReportMetrics] = [:]
    @Published var isLoadingMetrics = false

    var lastUpdatedLabel: String? { summary?.updatedTimeLabel }

    private let advertiserID: UInt64
    private let service      = AdDetailService.shared
    private let statsService = StatsService.shared
    private var page     = 1
    private let pageSize = 20

    // 30分钟本地指标缓存
    private var metricsLoadedKey: String? = nil
    private var metricsLoadedAt: Date?    = nil
    private let metricsCacheTTL: TimeInterval = 30 * 60

    init(advertiserID: UInt64) { self.advertiserID = advertiserID }

    // MARK: - 加载 / 刷新 / 分页

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; page = 1
        do {
            let (fetched, pagination) = try await service.campaigns(advertiserID: advertiserID, page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = msg(error) }
        isLoading = false
        await loadSummary()
        await loadCampaignMetrics()
    }

    func refresh() async {
        page = 1; error = nil
        do {
            let (fetched, pagination) = try await service.campaigns(advertiserID: advertiserID, page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = msg(error) }
        await loadSummary()
        metricsLoadedKey = nil // 刷新时强制重新拉取
        await loadCampaignMetrics()
    }

    func loadCampaignMetrics() async {
        guard !items.isEmpty else { return }

        let r = dateFilter.dateRange
        let cacheKey = "\(advertiserID)-\(r.from)-\(r.to)"

        // 30分钟内已缓存则跳过
        if let key = metricsLoadedKey, let loadedAt = metricsLoadedAt,
           key == cacheKey, Date().timeIntervalSince(loadedAt) < metricsCacheTTL {
            return
        }

        isLoadingMetrics = true
        let ids = items.map { $0.campaignID }
        if let resp = try? await statsService.campaignReport(
            advertiserDBID: advertiserID,
            campaignIDs: ids,
            startDate: r.from,
            endDate: r.to
        ) {
            var map: [String: CampaignReportMetrics] = [:]
            for m in resp.list { map[m.campaignID] = m }
            campaignMetrics = map
            metricsLoadedKey = cacheKey
            metricsLoadedAt  = Date()
        }
        isLoadingMetrics = false
    }

    func loadSummary() async {
        summaryLoading = true
        let r = dateFilter.dateRange
        summary = try? await statsService.summary(scope: "advertiser", scopeID: advertiserID,
                                                  dateFrom: r.from, dateTo: r.to)
        summaryLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let (fetched, pagination) = try await service.campaigns(advertiserID: advertiserID, page: page)
            items  += fetched
            hasMore = pagination.hasMore
            page   += 1
        } catch { self.error = msg(error) }
        isLoadingMore = false
        metricsLoadedKey = nil // 新页加载后重新拉取新增条目
        await loadCampaignMetrics()
    }

    // MARK: - 写操作

    /// BudgetEditSheet 调用：提交新预算
    func updateBudget(item: CampaignItem, budget: Double) async {
        do {
            try await service.updateCampaignBudget(id: item.id, budget: budget)
            await refresh()
        } catch { self.error = msg(error) }
    }

    /// 确认弹窗确认后调用
    func updateStatus(item: CampaignItem, action: String) async {
        updatingStatusID = item.id
        defer { updatingStatusID = nil }
        do {
            try await service.updateCampaignStatus(id: item.id, action: action)
            await refresh()
        } catch { self.error = msg(error) }
    }

    private func msg(_ e: Error) -> String? {
        if e is CancellationError { return nil }
        return (e as? APIError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - CampaignListView

struct CampaignListView: View {

    let advertiser: AdvertiserListItem
    @StateObject private var vm: CampaignListViewModel

    init(advertiser: AdvertiserListItem) {
        self.advertiser = advertiser
        _vm = StateObject(wrappedValue: CampaignListViewModel(advertiserID: advertiser.id))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.items.isEmpty && !vm.isLoading {
                emptyView("暂无推广系列")
            } else {
                list
            }
        }
        // 通用错误 alert
        .alert("操作失败", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        // I7：状态切换确认弹窗
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
                Text(target.campaignName)
            }
        }
        .task { await vm.load() }
    }

    // MARK: - 列表

    private var list: some View {
        List {
            ForEach(vm.items) { item in
                CampaignRow(item: item, isUpdatingStatus: vm.updatingStatusID == item.id)
                    // 左滑：改预算
                    .swipeActions(edge: .leading) {
                        Button { vm.budgetTarget = item } label: {
                            Label("改预算", systemImage: "pencil.circle.fill")
                        }
                        .tint(.blue)
                    }
                    // 右滑：先弹确认再切换状态
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
        // I7：预算编辑 Sheet
        .sheet(item: $vm.budgetTarget) { item in
            BudgetEditSheet(
                itemName:      item.campaignName,
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
        return target.status.isAdActive ? "确认暂停推广系列？" : "确认开启推广系列？"
    }
}

// MARK: - CampaignRow

struct CampaignRow: View {
    let item: CampaignItem
    let isUpdatingStatus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.campaignName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if isUpdatingStatus {
                    ProgressView().scaleEffect(0.7)
                } else {
                    StatusBadge(status: item.status)
                }
            }
            if !item.objective.isEmpty {
                Label(item.objective, systemImage: "target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                metricView(label: item.budgetMode.budgetModeLabel,
                           value: item.budgetMode == "BUDGET_MODE_INFINITE"
                               ? "不限" : item.budget.formatted(.number.precision(.fractionLength(2))))
                metricView(label: "消耗",
                           value: item.spend.formatted(.number.precision(.fractionLength(2))))
            }
        }
        .padding(.vertical, 4)
    }

    private func metricView(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.tertiary)
            Text(value).font(.caption.weight(.medium))
        }
    }
}

// MARK: - 共用子组件（同模块文件均可访问）

struct StatusBadge: View {
    let status: String
    var body: some View {
        Text(status.adStatusLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(status.adStatusColor.opacity(0.12))
            .foregroundStyle(status.adStatusColor)
            .clipShape(Capsule())
    }
}

func emptyView(_ text: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(.secondary)
        Text(text).font(.subheadline).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

var loadingMoreRow: some View {
    HStack { Spacer(); ProgressView(); Spacer() }.listRowSeparator(.hidden)
}
