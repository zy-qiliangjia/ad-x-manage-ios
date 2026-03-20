import SwiftUI

// MARK: - 导航目标

enum AdsNav: Hashable {
    case campaigns(AdvertiserListItem)
    case adGroups(advertiser: AdvertiserListItem, campaign: CampaignItem)
    case ads(advertiser: AdvertiserListItem, adgroup: AdGroupItem)
    // 全量视图
    case allCampaigns(platform: Platform?)
    case allAdGroups(platform: Platform?)
    case allAds(platform: Platform?)
    // 账号作用域跨层跳转
    case adGroupsForAccount(AdvertiserListItem)
    case adsForAccount(AdvertiserListItem)
}

// MARK: - AdsManageView

struct AdsManageView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm       = AdsManageListViewModel()
    @StateObject private var oauthVM  = OAuthViewModel()
    @State private var navPath: [AdsNav] = []
    @State private var showPlatformSelection = false

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 0) {
                // 维度 Tab（账号层级 active）
                DimensionTabRow(activeDimension: .account) { dim in
                    switch dim {
                    case .account:  break
                    case .campaign: navPath = [.allCampaigns(platform: vm.platformFilter)]
                    case .adGroup:  navPath = [.allAdGroups(platform: vm.platformFilter)]
                    case .ad:       navPath = [.allAds(platform: vm.platformFilter)]
                    }
                }

                content
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("广告管理")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AdsNav.self) { dest in
                switch dest {
                case .campaigns(let adv):
                    AdsCampaignView(advertiser: adv, navPath: $navPath)
                case .adGroups(let adv, let camp):
                    AdsAdGroupView(advertiser: adv, campaign: camp, navPath: $navPath)
                case .ads(let adv, let adgroup):
                    AdsAdView(advertiser: adv, adgroup: adgroup)
                case .allCampaigns(let platform):
                    AdsAllCampaignsView(navPath: $navPath, initialPlatform: platform)
                case .allAdGroups(let platform):
                    AdsAllAdGroupsView(navPath: $navPath, initialPlatform: platform)
                case .allAds(let platform):
                    AdsAllAdsView(navPath: $navPath, initialPlatform: platform)
                case .adGroupsForAccount(let adv):
                    AdsAdGroupsForAccountView(advertiser: adv, navPath: $navPath)
                case .adsForAccount(let adv):
                    AdsAdsForAccountView(advertiser: adv)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPlatformSelection = true } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showPlatformSelection) {
                PlatformSelectionView { platform in oauthVM.authorize(platform: platform) }
            }
            .sheet(isPresented: $oauthVM.isPresented) {
                OAuthProgressView(vm: oauthVM) { _ in Task { await vm.refresh() } }
            }
            .sheet(item: $vm.budgetTarget) { item in
                BudgetEditSheet(
                    itemName: item.advertiserName,
                    currentBudget: item.budget,
                    budgetMode: item.budgetMode
                ) { newBudget in await vm.updateBudget(item: item, budget: newBudget) }
            }
            .confirmationDialog(
                vm.statusConfirmTarget?.isActive == true ? "确认暂停账号？" : "确认开启账号？",
                isPresented: Binding(
                    get: { vm.statusConfirmTarget != nil },
                    set: { if !$0 { vm.statusConfirmTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let target = vm.statusConfirmTarget {
                    let isPause = target.isActive
                    Button(isPause ? "暂停" : "开启", role: isPause ? .destructive : nil) {
                        vm.statusConfirmTarget = nil
                        Task { await vm.updateStatus(item: target, action: isPause ? "pause" : "enable") }
                    }
                    Button("取消", role: .cancel) { vm.statusConfirmTarget = nil }
                }
            } message: {
                if let target = vm.statusConfirmTarget { Text(target.advertiserName) }
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    Picker("平台", selection: $vm.platformFilter) {
                        Text("全部").tag(Platform?.none)
                        ForEach(Platform.allCases) { p in
                            Text(p.displayName).tag(Platform?.some(p))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    DateRangePickerView(
                        startDate: $vm.selectedStartDate,
                        endDate:   $vm.selectedEndDate
                    ) { vm.onDateRangeChanged() }
                    Divider()
                }
                .background(.bar)
            }
            .searchable(text: $vm.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "搜索账号名称或 ID")
            .alert("请求失败", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("确定", role: .cancel) { vm.error = nil }
            } message: { Text(vm.error ?? "") }
        }
        .task { await vm.load() }
        .onChange(of: appState.isLoggedIn) { _, isLoggedIn in
            if !isLoggedIn { navPath = [] }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.items.isEmpty {
            ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.items.isEmpty && !vm.isLoading {
            emptyView("暂无广告账号")
        } else {
            ScrollView {
                LazyVStack(spacing: AppTheme.Spacing.md) {
                    // 汇总卡片（日期由顶部筛选条控制）
                    AdsSummaryCardView(
                        scopeLabel: "全部账号",
                        spend:       vm.totalMetrics?.spend       ?? 0,
                        clicks:      vm.totalMetrics?.clicks      ?? 0,
                        impressions: vm.totalMetrics?.impressions ?? 0,
                        conversions: vm.totalMetrics?.conversion  ?? 0,
                        dateFilter:  .constant(.last30Days),
                        isLoadingSummary: vm.isLoadingMetrics,
                        showDateTabs: false
                    )

                    ForEach(vm.items) { adv in
                        AdsAccountCardView(
                            advertiser: adv,
                            isUpdating: vm.updatingStatusID == adv.id,
                            metrics: vm.reportMetrics[adv.advertiserID],
                            isLoadingMetrics: vm.isLoadingMetrics,
                            onBudget: { vm.budgetTarget = adv },
                            onToggle: { vm.statusConfirmTarget = adv },
                            onDrill: { navPath.append(.campaigns(adv)) }
                        )
                        .onAppear {
                            if adv.id == vm.items.last?.id {
                                Task { await vm.loadMore() }
                            }
                        }
                    }
                    if vm.isLoadingMore { ProgressView().padding() }

                    // 合计行
                    if !vm.items.isEmpty {
                        MetricsSummaryRow(
                            total: vm.totalMetrics,
                            isLoading: vm.isLoadingMetrics
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.vertical, AppTheme.Spacing.md)
            }
            .refreshable { await vm.refresh() }
        }
    }
}

// MARK: - AdsManageListViewModel

@MainActor
final class AdsManageListViewModel: ObservableObject {

    @Published var items: [AdvertiserListItem] = []
    @Published var isLoading       = false
    @Published var isLoadingMore   = false
    @Published var hasMore         = false
    @Published var error: String?  = nil
    @Published var searchText      = "" { didSet { scheduleSearch() } }
    @Published var platformFilter: Platform? = nil { didSet { Task { await refresh() } } }
    @Published var budgetTarget: AdvertiserListItem?        = nil
    @Published var statusConfirmTarget: AdvertiserListItem? = nil
    @Published var updatingStatusID: UInt64?                = nil

    // ── 报表指标（按广告主 ID 缓存，切换日期时清空）──────────────
    @Published var reportMetrics: [String: AdvertiserReportMetrics] = [:]
    @Published var totalMetrics: AdvertiserReportMetrics? = nil
    @Published var isLoadingMetrics = false

    // ── 日期筛选（自定义，最大30天）─────────────────────────────
    @Published var selectedStartDate: Date = Calendar.current.date(
        byAdding: .day, value: -29,
        to: Calendar.current.startOfDay(for: Date())
    )!
    @Published var selectedEndDate: Date = Calendar.current.startOfDay(for: Date())

    private let service      = AdvertiserService.shared
    private let statsService = StatsService.shared
    private var page     = 1
    private let pageSize = 20
    private var searchTask: Task<Void, Never>? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    var startDateString: String { Self.dateFormatter.string(from: selectedStartDate) }
    var endDateString: String   { Self.dateFormatter.string(from: selectedEndDate) }

    // MARK: - Load

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; page = 1
        do {
            let (fetched, pagination) = try await fetch(page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = msg(error) }
        isLoading = false
        await loadMetrics()
    }

    func refresh() async {
        page = 1; error = nil
        reportMetrics = [:]; totalMetrics = nil
        do {
            let (fetched, pagination) = try await fetch(page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = msg(error) }
        await loadMetrics()
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let (fetched, pagination) = try await fetch(page: page)
            items  += fetched
            hasMore = pagination.hasMore
            page   += 1
        } catch { self.error = msg(error) }
        isLoadingMore = false
        await loadMetrics()
    }

    // MARK: - Metrics (batched, cached)

    /// 拉取报表指标。已缓存的 ID 不重复请求；每平台每批最多 5 个广告主。
    func loadMetrics() async {
        guard !items.isEmpty else { return }
        isLoadingMetrics = true

        let uncached = items.filter { reportMetrics[$0.advertiserID] == nil }
        if !uncached.isEmpty {
            var byPlatform: [String: [String]] = [:]
            for item in uncached {
                byPlatform[item.platform, default: []].append(item.advertiserID)
            }

            await withTaskGroup(of: [(String, AdvertiserReportMetrics)].self) { group in
                for (plt, ids) in byPlatform {
                    for batch in ids.chunked(by: 5) {
                        group.addTask { [weak self] in
                            guard let self else { return [] }
                            do {
                                let resp = try await self.statsService.advertiserReport(
                                    platform: plt,
                                    advertiserIDs: batch,
                                    startDate: self.startDateString,
                                    endDate:   self.endDateString
                                )
                                return resp.list.map { ($0.advertiserID, $0) }
                            } catch { return [] }
                        }
                    }
                }
                for await results in group {
                    for (id, metric) in results { reportMetrics[id] = metric }
                }
            }
        }

        totalMetrics     = computeTotal()
        isLoadingMetrics = false
    }

    /// 日期变更：清空缓存后重新拉取
    func onDateRangeChanged() {
        reportMetrics = [:]; totalMetrics = nil
        Task { await loadMetrics() }
    }

    // MARK: - Write

    func updateBudget(item: AdvertiserListItem, budget: Double) async {
        do {
            try await service.updateBudget(id: item.id, budget: budget)
            await refresh()
        } catch { self.error = msg(error) }
    }

    func updateStatus(item: AdvertiserListItem, action: String) async {
        updatingStatusID = item.id
        let previousItems = items
        do {
            try await service.updateStatus(id: item.id, action: action)
            await refresh()
        } catch {
            items = previousItems
            self.error = msg(error)
        }
        updatingStatusID = nil
    }

    // MARK: - Private

    private func fetch(page: Int) async throws -> ([AdvertiserListItem], APIPagination) {
        try await service.list(platform: platformFilter?.rawValue, keyword: searchText,
                               page: page, pageSize: pageSize)
    }

    private func computeTotal() -> AdvertiserReportMetrics? {
        let all = items.compactMap { reportMetrics[$0.advertiserID] }
        guard !all.isEmpty else { return nil }
        return all.dropFirst().reduce(all[0]) { mergeMetrics($0, $1) }
    }

    private func mergeMetrics(_ a: AdvertiserReportMetrics,
                               _ b: AdvertiserReportMetrics) -> AdvertiserReportMetrics {
        let dict: [String: Any] = [
            "advertiser_id": "-",
            "spend": a.spend + b.spend,
            "clicks": a.clicks + b.clicks,
            "impressions": a.impressions + b.impressions,
            "conversion": a.conversion + b.conversion,
            "cost_per_conversion": 0.0,
            "cpa": 0.0,
            "currency": "",
            "daily_budget": a.dailyBudget + b.dailyBudget
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let result = try? JSONDecoder().decode(AdvertiserReportMetrics.self, from: data) {
            return result
        }
        return a
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    private func msg(_ e: Error) -> String? {
        if e is CancellationError { return nil }
        return (e as? APIError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - Array chunked helper

private extension Array {
    func chunked(by size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - AdsAccountCardView (账号层级卡片)

private struct AdsAccountCardView: View {
    let advertiser: AdvertiserListItem
    let isUpdating: Bool
    let metrics: AdvertiserReportMetrics?
    let isLoadingMetrics: Bool
    let onBudget: () -> Void
    let onToggle: () -> Void
    let onDrill: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：平台 avatar + 账号名/ID + 状态开关
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.tiktokDark, Color(red: 0.2, green: 0.2, blue: 0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Text(advertiser.platformEnum == .kwai ? "K" : "T")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(advertiser.advertiserName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(advertiser.advertiserID)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                if isUpdating {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Toggle("", isOn: .constant(advertiser.isActive))
                        .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.success))
                        .labelsHidden()
                        .scaleEffect(0.85)
                        .onTapGesture { onToggle() }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.md)

            // 指标网格（消耗/点击/展示/转化/CPA/日预算）
            Divider()
                .padding(.horizontal, AppTheme.Spacing.lg)

            if isLoadingMetrics && metrics == nil {
                MetricsSkeletonGrid()
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .padding(.horizontal, AppTheme.Spacing.lg)
            } else {
                AdvertiserMetricsGrid(
                    metrics: metrics,
                    currency: advertiser.currency
                )
                .padding(.vertical, AppTheme.Spacing.sm)
                .padding(.horizontal, AppTheme.Spacing.lg)
            }

            Divider().padding(.horizontal, AppTheme.Spacing.lg)

            // 底部：调整预算按钮 + 进入推广系列
            HStack {
                Button(action: onBudget) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 12))
                        Text("调整预算")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.primaryBg)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onDrill) {
                    HStack(spacing: 4) {
                        Text("推广系列")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
        .contentShape(Rectangle())
    }

}

// MARK: - AdsCampaignView

struct AdsCampaignView: View {

    let advertiser: AdvertiserListItem
    @Binding var navPath: [AdsNav]
    @StateObject private var vm: CampaignListViewModel

    init(advertiser: AdvertiserListItem, navPath: Binding<[AdsNav]>) {
        self.advertiser = advertiser
        _navPath        = navPath
        _vm = StateObject(wrappedValue: CampaignListViewModel(advertiserID: advertiser.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 维度 Tab
            DimensionTabRow(activeDimension: .campaign) { dim in
                switch dim {
                case .account:  navPath.removeAll()
                case .campaign: break
                case .adGroup:  navPath.append(.adGroupsForAccount(advertiser))
                case .ad:       navPath.append(.adsForAccount(advertiser))
                }
            }

            // 面包屑
            BreadcrumbView(nodes: [
                BreadcrumbNode(id: 0, label: "全部账号") { navPath.removeAll() },
                BreadcrumbNode(id: 1, label: advertiser.advertiserName, action: nil)
            ])

            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty && !vm.isLoading {
                    emptyView("暂无推广系列")
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.md) {
                            // 汇总卡片
                            AdsSummaryCardView(
                                scopeLabel: advertiser.advertiserName,
                                spend:       vm.summary?.spend        ?? vm.items.reduce(0) { $0 + $1.spend },
                                clicks:      vm.summary?.clicks       ?? 0,
                                impressions: vm.summary?.impressions  ?? 0,
                                conversions: vm.summary?.conversions  ?? 0,
                                dateFilter:  Binding(get: { vm.dateFilter }, set: { vm.dateFilter = $0 }),
                                isLoadingSummary: vm.summaryLoading
                            )

                            ForEach(vm.items) { item in
                                CampaignManageCard(
                                    item: item,
                                    isUpdating: vm.updatingStatusID == item.id,
                                    metrics: vm.campaignMetrics[item.campaignID],
                                    isLoadingMetrics: vm.isLoadingMetrics,
                                    onBudget: { vm.budgetTarget = item },
                                    onToggle: { vm.statusConfirmTarget = item },
                                    onDrill: { navPath.append(.adGroups(advertiser: advertiser, campaign: item)) }
                                )
                                .onAppear {
                                    if item.id == vm.items.last?.id { Task { await vm.loadMore() } }
                                }
                            }
                            if vm.isLoadingMore { ProgressView().padding() }
                        }
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.vertical, AppTheme.Spacing.md)
                    }
                    .refreshable { await vm.refresh() }
                    .sheet(item: $vm.budgetTarget) { item in
                        BudgetEditSheet(
                            itemName: item.campaignName,
                            currentBudget: item.budget,
                            budgetMode: item.budgetMode
                        ) { newBudget in await vm.updateBudget(item: item, budget: newBudget) }
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(advertiser.advertiserName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.summaryLoading {
                    ProgressView().scaleEffect(0.7)
                } else if let label = vm.lastUpdatedLabel {
                    Text("更新于 \(label)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { vm.error != nil }, set: { if !$0 { vm.error = nil } }
        )) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .confirmationDialog(
            vm.statusConfirmTarget?.status.isAdActive == true ? "确认暂停推广系列？" : "确认开启推广系列？",
            isPresented: Binding(get: { vm.statusConfirmTarget != nil }, set: { if !$0 { vm.statusConfirmTarget = nil } }),
            titleVisibility: .visible
        ) {
            if let target = vm.statusConfirmTarget {
                let isPause = target.status.isAdActive
                Button(isPause ? "暂停" : "开启", role: isPause ? .destructive : nil) {
                    vm.statusConfirmTarget = nil
                    Task { await vm.updateStatus(item: target, action: isPause ? "pause" : "enable") }
                }
                Button("取消", role: .cancel) { vm.statusConfirmTarget = nil }
            }
        } message: {
            if let target = vm.statusConfirmTarget { Text(target.campaignName) }
        }
        .task { await vm.load() }
    }
}

// MARK: - AdsAdGroupView

struct AdsAdGroupView: View {

    let advertiser: AdvertiserListItem
    let campaign: CampaignItem
    @Binding var navPath: [AdsNav]
    @StateObject private var vm: AdGroupListViewModel

    init(advertiser: AdvertiserListItem, campaign: CampaignItem, navPath: Binding<[AdsNav]>) {
        self.advertiser = advertiser
        self.campaign   = campaign
        _navPath        = navPath
        _vm = StateObject(wrappedValue: AdGroupListViewModel(advertiserID: advertiser.id, campaignID: campaign.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            DimensionTabRow(activeDimension: .adGroup) { dim in
                switch dim {
                case .account:  navPath.removeAll()
                case .campaign: navPath.removeLast()
                case .adGroup:  break
                case .ad:       navPath.append(.adsForAccount(advertiser))
                }
            }

            BreadcrumbView(nodes: [
                BreadcrumbNode(id: 0, label: "全部账号") { navPath.removeAll() },
                BreadcrumbNode(id: 1, label: advertiser.advertiserName) {
                    navPath.removeLast(navPath.count - 1)
                },
                BreadcrumbNode(id: 2, label: campaign.campaignName, action: nil)
            ])

            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty && !vm.isLoading {
                    emptyView("暂无广告组")
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.md) {
                            AdsSummaryCardView(
                                scopeLabel: campaign.campaignName,
                                spend:       vm.summary?.spend        ?? vm.items.reduce(0) { $0 + $1.spend },
                                clicks:      vm.summary?.clicks       ?? 0,
                                impressions: vm.summary?.impressions  ?? 0,
                                conversions: vm.summary?.conversions  ?? 0,
                                dateFilter:  Binding(get: { vm.dateFilter }, set: { vm.dateFilter = $0 }),
                                isLoadingSummary: vm.summaryLoading
                            )

                            ForEach(vm.items) { item in
                                AdGroupManageCard(
                                    item: item,
                                    isUpdating: vm.updatingStatusID == item.id,
                                    metrics: vm.adGroupMetrics[item.adgroupID],
                                    isLoadingMetrics: vm.isLoadingMetrics,
                                    onBudget: { vm.budgetTarget = item },
                                    onToggle: { vm.statusConfirmTarget = item },
                                    onDrill: { navPath.append(.ads(advertiser: advertiser, adgroup: item)) }
                                )
                                .onAppear {
                                    if item.id == vm.items.last?.id { Task { await vm.loadMore() } }
                                }
                            }
                            if vm.isLoadingMore { ProgressView().padding() }
                        }
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.vertical, AppTheme.Spacing.md)
                    }
                    .refreshable { await vm.refresh() }
                    .sheet(item: $vm.budgetTarget) { item in
                        BudgetEditSheet(
                            itemName: item.adgroupName,
                            currentBudget: item.budget,
                            budgetMode: item.budgetMode
                        ) { newBudget in await vm.updateBudget(item: item, budget: newBudget) }
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(campaign.campaignName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.summaryLoading {
                    ProgressView().scaleEffect(0.7)
                } else if let label = vm.lastUpdatedLabel {
                    Text("更新于 \(label)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { vm.error != nil }, set: { if !$0 { vm.error = nil } }
        )) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .confirmationDialog(
            vm.statusConfirmTarget?.status.isAdActive == true ? "确认暂停广告组？" : "确认开启广告组？",
            isPresented: Binding(get: { vm.statusConfirmTarget != nil }, set: { if !$0 { vm.statusConfirmTarget = nil } }),
            titleVisibility: .visible
        ) {
            if let target = vm.statusConfirmTarget {
                let isPause = target.status.isAdActive
                Button(isPause ? "暂停" : "开启", role: isPause ? .destructive : nil) {
                    vm.statusConfirmTarget = nil
                    Task { await vm.updateStatus(item: target, action: isPause ? "pause" : "enable") }
                }
                Button("取消", role: .cancel) { vm.statusConfirmTarget = nil }
            }
        } message: {
            if let target = vm.statusConfirmTarget { Text(target.adgroupName) }
        }
        .task { await vm.load() }
    }
}

// MARK: - AdsAdView

struct AdsAdView: View {

    let advertiser: AdvertiserListItem
    let adgroup: AdGroupItem
    @StateObject private var vm: AdListViewModel

    init(advertiser: AdvertiserListItem, adgroup: AdGroupItem) {
        self.advertiser = advertiser
        self.adgroup    = adgroup
        _vm = StateObject(wrappedValue: AdListViewModel(advertiserID: advertiser.id, adgroupID: adgroup.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 汇总卡片
            AdsSummaryCardView(
                scopeLabel: adgroup.adgroupName,
                spend:       vm.summary?.spend        ?? 0,
                clicks:      vm.summary?.clicks       ?? 0,
                impressions: vm.summary?.impressions  ?? 0,
                conversions: vm.summary?.conversions  ?? 0,
                dateFilter:  Binding(get: { vm.dateFilter }, set: { vm.dateFilter = $0 }),
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
                    List {
                        ForEach(vm.items) { item in
                            AdRow(
                                item: item,
                                metrics: vm.adMetrics[item.adID],
                                isUpdatingStatus: vm.updatingStatusID == item.id
                            ) { vm.statusConfirmTarget = item }
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
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(adgroup.adgroupName)
        .navigationBarTitleDisplayMode(.inline)
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
        .searchable(text: $vm.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索广告 ID 或名称")
        .alert("操作失败", isPresented: Binding(
            get: { vm.error != nil }, set: { if !$0 { vm.error = nil } }
        )) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .confirmationDialog(
            vm.statusConfirmTarget?.status.isAdActive == true ? "确认暂停广告？" : "确认开启广告？",
            isPresented: Binding(
                get: { vm.statusConfirmTarget != nil },
                set: { if !$0 { vm.statusConfirmTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = vm.statusConfirmTarget {
                let isPause = target.status.isAdActive
                Button(isPause ? "暂停" : "开启", role: isPause ? .destructive : nil) {
                    vm.statusConfirmTarget = nil
                    Task { await vm.updateStatus(item: target, action: isPause ? "pause" : "enable") }
                }
                Button("取消", role: .cancel) { vm.statusConfirmTarget = nil }
            }
        } message: {
            if let target = vm.statusConfirmTarget { Text(target.adName) }
        }
        .task { await vm.load() }
    }
}

// MARK: - CampaignManageCard

private struct CampaignManageCard: View {
    let item: CampaignItem
    let isUpdating: Bool
    let metrics: CampaignReportMetrics?
    let isLoadingMetrics: Bool
    let onBudget: () -> Void
    let onToggle: () -> Void
    let onDrill: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：名称 + 状态徽章
            HStack(spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.campaignName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    if !item.objective.isEmpty {
                        Text(item.objective)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                Spacer()
                if isUpdating {
                    ProgressView().scaleEffect(0.8)
                } else {
                    StatusBadge(status: item.status)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.md)

            // 指标区域
            if isLoadingMetrics && metrics == nil {
                campaignMetricsSkeleton
            } else {
                campaignMetricsGrid
            }

            Divider().padding(.horizontal, AppTheme.Spacing.lg)

            // 底部：预算编辑 + 钻取
            HStack {
                Button(action: onBudget) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 12))
                        Text("调整预算")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.primaryBg)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onDrill) {
                    HStack(spacing: 4) {
                        Text("广告组")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
        .contentShape(Rectangle())
    }

    // 5格指标 + 操作按钮：消耗、点击、展示 / 转化、CPA、暂停开启
    private var campaignMetricsGrid: some View {
        let cpaVal = metrics.map { $0.cpa > 0 ? $0.cpa.statFormatted : "-" } ?? "-"
        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppTheme.Spacing.sm
        ) {
            metricCell(label: "消耗",    value: metrics.map { $0.spend.statFormatted }      ?? item.spend.statFormatted)
            metricCell(label: "点击",    value: metrics.map { "\($0.clicks)" }              ?? "-")
            metricCell(label: "展示",    value: metrics.map { "\($0.impressions)" }         ?? "-")
            metricCell(label: "转化",    value: metrics.map { "\($0.conversion)" }          ?? "-")
            metricCell(label: "CPA",     value: cpaVal)
            toggleButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var toggleButton: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: item.status.isAdActive ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.status.isAdActive ? Color.orange : AppTheme.Colors.success)
                Text(item.status.isAdActive ? "暂停" : "开启")
                    .font(.system(size: 10))
                    .foregroundStyle(item.status.isAdActive ? Color.orange : AppTheme.Colors.success)
            }
        }
        .buttonStyle(.plain)
    }

    // 加载骨架
    private var campaignMetricsSkeleton: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppTheme.Spacing.sm
        ) {
            ForEach(0..<5, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.Colors.textSecondary.opacity(0.15))
                        .frame(width: 44, height: 13)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.Colors.textSecondary.opacity(0.10))
                        .frame(width: 28, height: 10)
                }
            }
            toggleButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.Colors.textPrimary)
            Text(label).font(.system(size: 10)).foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - AdGroupManageCard

struct AdGroupManageCard: View {
    let item: AdGroupItem
    let isUpdating: Bool
    let metrics: AdGroupReportMetrics?
    let isLoadingMetrics: Bool
    let onBudget: () -> Void
    let onToggle: () -> Void
    let onDrill: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.adgroupName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    Text("ID: \(item.adgroupID)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
                if isUpdating {
                    ProgressView().scaleEffect(0.8)
                } else {
                    StatusBadge(status: item.status)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.md)

            // 指标区域
            if isLoadingMetrics && metrics == nil {
                adGroupMetricsSkeleton
            } else {
                adGroupMetricsGrid
            }

            Divider().padding(.horizontal, AppTheme.Spacing.lg)

            HStack {
                Button(action: onBudget) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill").font(.system(size: 12))
                        Text("调整预算").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.primaryBg)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onDrill) {
                    HStack(spacing: 4) {
                        Text("广告").font(.system(size: 12)).foregroundStyle(AppTheme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
        .contentShape(Rectangle())
    }

    // 5格指标 + 操作按钮：消耗、点击、展示 / 转化、CPA、暂停开启
    private var adGroupMetricsGrid: some View {
        let cpaVal = metrics.map { $0.cpa > 0 ? $0.cpa.statFormatted : "-" } ?? "-"
        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppTheme.Spacing.sm
        ) {
            metricCell(label: "消耗",    value: metrics.map { $0.spend.statFormatted }      ?? item.spend.statFormatted)
            metricCell(label: "点击",    value: metrics.map { "\($0.clicks)" }              ?? "-")
            metricCell(label: "展示",    value: metrics.map { "\($0.impressions)" }         ?? "-")
            metricCell(label: "转化",    value: metrics.map { "\($0.conversion)" }          ?? "-")
            metricCell(label: "CPA",     value: cpaVal)
            toggleButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var toggleButton: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: item.status.isAdActive ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.status.isAdActive ? Color.orange : AppTheme.Colors.success)
                Text(item.status.isAdActive ? "暂停" : "开启")
                    .font(.system(size: 10))
                    .foregroundStyle(item.status.isAdActive ? Color.orange : AppTheme.Colors.success)
            }
        }
        .buttonStyle(.plain)
    }

    // 加载骨架
    private var adGroupMetricsSkeleton: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppTheme.Spacing.sm
        ) {
            ForEach(0..<5, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.Colors.textSecondary.opacity(0.15))
                        .frame(width: 44, height: 13)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.Colors.textSecondary.opacity(0.10))
                        .frame(width: 28, height: 10)
                }
            }
            toggleButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.Colors.textPrimary)
            Text(label).font(.system(size: 10)).foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - AllCampaignsViewModel

@MainActor
final class AllCampaignsViewModel: ObservableObject {
    @Published var items: [CampaignItem] = []
    @Published var isLoading     = false
    @Published var isLoadingMore = false
    @Published var hasMore       = false
    @Published var error: String? = nil
    @Published var platformFilter: Platform? { didSet { Task { await refresh() } } }

    @Published var dateFilter: DateRangeFilter = .last7Days {
        didSet {
            metricsLoadedKey = nil
            Task { await loadCampaignMetrics() }
        }
    }
    @Published var campaignMetrics: [String: CampaignReportMetrics] = [:]
    @Published var isLoadingMetrics = false

    @Published var budgetTarget: CampaignItem?        = nil
    @Published var statusConfirmTarget: CampaignItem? = nil
    @Published var updatingStatusID: UInt64?          = nil

    private let service      = AdDetailService.shared
    private let statsService = StatsService.shared
    private var page         = 1
    private let pageSize     = 20

    // 30分钟本地指标缓存
    private var metricsLoadedKey: String? = nil
    private var metricsLoadedAt: Date?    = nil
    private let metricsCacheTTL: TimeInterval = 30 * 60

    init(initialPlatform: Platform? = nil) {
        _platformFilter = Published(wrappedValue: initialPlatform)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; page = 1
        do {
            let (fetched, p) = try await service.allCampaigns(platform: platformFilter?.rawValue, page: 1, pageSize: pageSize)
            items = fetched; hasMore = p.hasMore; page = 2
        } catch { self.error = msg(error) }
        isLoading = false
        await loadCampaignMetrics()
    }

    func refresh() async {
        page = 1; error = nil
        do {
            let (fetched, p) = try await service.allCampaigns(platform: platformFilter?.rawValue, page: 1, pageSize: pageSize)
            items = fetched; hasMore = p.hasMore; page = 2
        } catch { self.error = msg(error) }
        metricsLoadedKey = nil
        await loadCampaignMetrics()
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let (fetched, p) = try await service.allCampaigns(platform: platformFilter?.rawValue, page: page, pageSize: pageSize)
            items += fetched; hasMore = p.hasMore; page += 1
        } catch { self.error = msg(error) }
        isLoadingMore = false
        metricsLoadedKey = nil
        await loadCampaignMetrics()
    }

    func updateBudget(item: CampaignItem, budget: Double) async {
        do {
            try await service.updateCampaignBudget(id: item.id, budget: budget)
            await refresh()
        } catch { self.error = msg(error) }
    }

    func updateStatus(item: CampaignItem, action: String) async {
        updatingStatusID = item.id
        defer { updatingStatusID = nil }
        do {
            try await service.updateCampaignStatus(id: item.id, action: action)
            await refresh()
        } catch { self.error = msg(error) }
    }

    func loadCampaignMetrics() async {
        guard !items.isEmpty else { return }

        let r = dateFilter.dateRange
        let cacheKey = "\(platformFilter?.rawValue ?? "all")-\(r.from)-\(r.to)-\(items.count)"

        if let key = metricsLoadedKey, let loadedAt = metricsLoadedAt,
           key == cacheKey, Date().timeIntervalSince(loadedAt) < metricsCacheTTL {
            return
        }

        isLoadingMetrics = true

        // 按广告主 ID 分组，逐广告主调用报表接口
        var byAdvertiser: [UInt64: [String]] = [:]
        for item in items {
            byAdvertiser[item.advertiserID, default: []].append(item.campaignID)
        }

        for (advID, campIDs) in byAdvertiser {
            if let resp = try? await statsService.campaignReport(
                advertiserDBID: advID,
                campaignIDs: campIDs,
                startDate: r.from,
                endDate: r.to
            ) {
                for m in resp.list { campaignMetrics[m.campaignID] = m }
            }
        }

        metricsLoadedKey = cacheKey
        metricsLoadedAt  = Date()
        isLoadingMetrics = false
    }

    private func msg(_ e: Error) -> String? {
        if e is CancellationError { return nil }
        return (e as? APIError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - AllAdGroupsViewModel

@MainActor
final class AllAdGroupsViewModel: ObservableObject {
    @Published var items: [AdGroupItem] = []
    @Published var isLoading     = false
    @Published var isLoadingMore = false
    @Published var hasMore       = false
    @Published var error: String? = nil
    @Published var platformFilter: Platform? { didSet { Task { await refresh() } } }

    @Published var budgetTarget: AdGroupItem?        = nil
    @Published var statusConfirmTarget: AdGroupItem? = nil
    @Published var updatingStatusID: UInt64?         = nil
    @Published var adGroupMetrics: [String: AdGroupReportMetrics] = [:]
    let isLoadingMetrics = false

    private let service  = AdDetailService.shared
    private var page     = 1
    private let pageSize = 20

    init(initialPlatform: Platform? = nil) {
        _platformFilter = Published(wrappedValue: initialPlatform)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; page = 1
        do {
            let (fetched, p) = try await service.allAdGroups(platform: platformFilter?.rawValue, page: 1, pageSize: pageSize)
            items = fetched; hasMore = p.hasMore; page = 2
        } catch { self.error = msg(error) }
        isLoading = false
    }

    func refresh() async {
        page = 1; error = nil
        do {
            let (fetched, p) = try await service.allAdGroups(platform: platformFilter?.rawValue, page: 1, pageSize: pageSize)
            items = fetched; hasMore = p.hasMore; page = 2
        } catch { self.error = msg(error) }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let (fetched, p) = try await service.allAdGroups(platform: platformFilter?.rawValue, page: page, pageSize: pageSize)
            items += fetched; hasMore = p.hasMore; page += 1
        } catch { self.error = msg(error) }
        isLoadingMore = false
    }

    func updateBudget(item: AdGroupItem, budget: Double) async {
        do {
            try await service.updateAdGroupBudget(id: item.id, budget: budget)
            await refresh()
        } catch { self.error = msg(error) }
    }

    func updateStatus(item: AdGroupItem, action: String) async {
        updatingStatusID = item.id
        defer { updatingStatusID = nil }
        do {
            try await service.updateAdGroupStatus(id: item.id, action: action)
            await refresh()
        } catch { self.error = msg(error) }
    }

    private func msg(_ e: Error) -> String? {
        if e is CancellationError { return nil }
        return (e as? APIError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - AllAdsViewModel

@MainActor
final class AllAdsViewModel: ObservableObject {
    @Published var items: [AdItem] = []
    @Published var isLoading     = false
    @Published var isLoadingMore = false
    @Published var hasMore       = false
    @Published var error: String? = nil
    @Published var platformFilter: Platform? { didSet { Task { await refresh() } } }
    @Published var searchText    = "" { didSet { scheduleSearch() } }

    @Published var statusConfirmTarget: AdItem?  = nil
    @Published var updatingStatusID: UInt64?     = nil

    private let service    = AdDetailService.shared
    private var page       = 1
    private let pageSize   = 20
    private var searchTask: Task<Void, Never>? = nil

    init(initialPlatform: Platform? = nil) {
        _platformFilter = Published(wrappedValue: initialPlatform)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; page = 1
        do {
            let (fetched, p) = try await service.allAds(platform: platformFilter?.rawValue, keyword: searchText, page: 1, pageSize: pageSize)
            items = fetched; hasMore = p.hasMore; page = 2
        } catch { self.error = msg(error) }
        isLoading = false
    }

    func refresh() async {
        page = 1; error = nil
        do {
            let (fetched, p) = try await service.allAds(platform: platformFilter?.rawValue, keyword: searchText, page: 1, pageSize: pageSize)
            items = fetched; hasMore = p.hasMore; page = 2
        } catch { self.error = msg(error) }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let (fetched, p) = try await service.allAds(platform: platformFilter?.rawValue, keyword: searchText, page: page, pageSize: pageSize)
            items += fetched; hasMore = p.hasMore; page += 1
        } catch { self.error = msg(error) }
        isLoadingMore = false
    }

    func updateStatus(item: AdItem, action: String) async {
        updatingStatusID = item.id
        defer { updatingStatusID = nil }
        do {
            try await service.updateAdStatus(id: item.id, action: action)
            await refresh()
        } catch { self.error = msg(error) }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    private func msg(_ e: Error) -> String? {
        if e is CancellationError { return nil }
        return (e as? APIError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - AdsAllCampaignsView

struct AdsAllCampaignsView: View {
    @Binding var navPath: [AdsNav]
    @StateObject private var vm: AllCampaignsViewModel

    init(navPath: Binding<[AdsNav]>, initialPlatform: Platform? = nil) {
        _navPath = navPath
        _vm = StateObject(wrappedValue: AllCampaignsViewModel(initialPlatform: initialPlatform))
    }

    var body: some View {
        VStack(spacing: 0) {
            DimensionTabRow(activeDimension: .campaign) { dim in
                switch dim {
                case .account:  navPath.removeAll()
                case .campaign: break
                case .adGroup:  navPath = [.allAdGroups(platform: vm.platformFilter)]
                case .ad:       navPath = [.allAds(platform: vm.platformFilter)]
                }
            }

            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty && !vm.isLoading {
                    emptyView("暂无推广系列")
                } else {
                    let totalSpend = vm.campaignMetrics.values.reduce(0.0) { $0 + $1.spend }
                    let totalClicks = vm.campaignMetrics.values.reduce(0) { $0 + $1.clicks }
                    let totalImpressions = vm.campaignMetrics.values.reduce(0) { $0 + $1.impressions }
                    let totalConversions = vm.campaignMetrics.values.reduce(0) { $0 + $1.conversion }
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.md) {
                            AdsSummaryCardView(
                                scopeLabel: "全部推广系列",
                                spend:       totalSpend > 0 ? totalSpend : vm.items.reduce(0) { $0 + $1.spend },
                                clicks:      totalClicks,
                                impressions: totalImpressions,
                                conversions: totalConversions,
                                dateFilter:  Binding(get: { vm.dateFilter }, set: { vm.dateFilter = $0 }),
                                isLoadingSummary: vm.isLoadingMetrics
                            )
                            ForEach(vm.items) { item in
                                CampaignManageCard(
                                    item: item,
                                    isUpdating: vm.updatingStatusID == item.id,
                                    metrics: vm.campaignMetrics[item.campaignID],
                                    isLoadingMetrics: vm.isLoadingMetrics,
                                    onBudget: { vm.budgetTarget = item },
                                    onToggle: { vm.statusConfirmTarget = item },
                                    onDrill: {
                                        let adv = AdvertiserListItem(
                                            id: item.advertiserID, platform: item.platform,
                                            advertiserID: String(item.advertiserID),
                                            advertiserName: item.advertiserName)
                                        navPath.append(.adGroups(advertiser: adv, campaign: item))
                                    }
                                )
                                .onAppear { if item.id == vm.items.last?.id { Task { await vm.loadMore() } } }
                            }
                            if vm.isLoadingMore { ProgressView().padding() }
                        }
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.vertical, AppTheme.Spacing.md)
                    }
                    .refreshable { await vm.refresh() }
                    .sheet(item: $vm.budgetTarget) { item in
                        BudgetEditSheet(
                            itemName: item.campaignName,
                            currentBudget: item.budget,
                            budgetMode: item.budgetMode
                        ) { newBudget in await vm.updateBudget(item: item, budget: newBudget) }
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("全部推广系列")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) { platformPicker($vm.platformFilter) }
        .alert("操作失败", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .confirmationDialog(
            vm.statusConfirmTarget?.status.isAdActive == true ? "确认暂停推广系列？" : "确认开启推广系列？",
            isPresented: Binding(get: { vm.statusConfirmTarget != nil }, set: { if !$0 { vm.statusConfirmTarget = nil } }),
            titleVisibility: .visible
        ) {
            if let target = vm.statusConfirmTarget {
                let isPause = target.status.isAdActive
                Button(isPause ? "暂停" : "开启", role: isPause ? .destructive : nil) {
                    vm.statusConfirmTarget = nil
                    Task { await vm.updateStatus(item: target, action: isPause ? "pause" : "enable") }
                }
                Button("取消", role: .cancel) { vm.statusConfirmTarget = nil }
            }
        } message: {
            if let target = vm.statusConfirmTarget { Text(target.campaignName) }
        }
        .task { await vm.load() }
    }
}

// MARK: - AdsAllAdGroupsView

struct AdsAllAdGroupsView: View {
    @Binding var navPath: [AdsNav]
    @StateObject private var vm: AllAdGroupsViewModel
    @State private var summaryDateFilter: DateRangeFilter = .last7Days

    init(navPath: Binding<[AdsNav]>, initialPlatform: Platform? = nil) {
        _navPath = navPath
        _vm = StateObject(wrappedValue: AllAdGroupsViewModel(initialPlatform: initialPlatform))
    }

    var body: some View {
        VStack(spacing: 0) {
            DimensionTabRow(activeDimension: .adGroup) { dim in
                switch dim {
                case .account:  navPath.removeAll()
                case .campaign: navPath = [.allCampaigns(platform: vm.platformFilter)]
                case .adGroup:  break
                case .ad:       navPath = [.allAds(platform: vm.platformFilter)]
                }
            }

            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty && !vm.isLoading {
                    emptyView("暂无广告组")
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.md) {
                            AdsSummaryCardView(
                                scopeLabel: "全部广告组",
                                spend:       vm.items.reduce(0) { $0 + $1.spend },
                                clicks:      vm.items.reduce(0) { $0 + $1.clicks },
                                impressions: vm.items.reduce(0) { $0 + $1.impressions },
                                conversions: vm.items.reduce(0) { $0 + $1.conversions },
                                dateFilter:  $summaryDateFilter,
                                isLoadingSummary: vm.isLoading
                            )
                            ForEach(vm.items) { item in
                                AdGroupManageCard(
                                    item: item,
                                    isUpdating: vm.updatingStatusID == item.id,
                                    metrics: vm.adGroupMetrics[item.adgroupID],
                                    isLoadingMetrics: vm.isLoadingMetrics,
                                    onBudget: { vm.budgetTarget = item },
                                    onToggle: { vm.statusConfirmTarget = item },
                                    onDrill: {
                                        let adv = AdvertiserListItem(
                                            id: item.advertiserID, platform: item.platform,
                                            advertiserID: String(item.advertiserID),
                                            advertiserName: item.advertiserName)
                                        navPath.append(.ads(advertiser: adv, adgroup: item))
                                    }
                                )
                                .onAppear { if item.id == vm.items.last?.id { Task { await vm.loadMore() } } }
                            }
                            if vm.isLoadingMore { ProgressView().padding() }
                        }
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.vertical, AppTheme.Spacing.md)
                    }
                    .refreshable { await vm.refresh() }
                    .sheet(item: $vm.budgetTarget) { item in
                        BudgetEditSheet(
                            itemName: item.adgroupName,
                            currentBudget: item.budget,
                            budgetMode: item.budgetMode
                        ) { newBudget in await vm.updateBudget(item: item, budget: newBudget) }
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("全部广告组")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) { platformPicker($vm.platformFilter) }
        .alert("操作失败", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .confirmationDialog(
            vm.statusConfirmTarget?.status.isAdActive == true ? "确认暂停广告组？" : "确认开启广告组？",
            isPresented: Binding(get: { vm.statusConfirmTarget != nil }, set: { if !$0 { vm.statusConfirmTarget = nil } }),
            titleVisibility: .visible
        ) {
            if let target = vm.statusConfirmTarget {
                let isPause = target.status.isAdActive
                Button(isPause ? "暂停" : "开启", role: isPause ? .destructive : nil) {
                    vm.statusConfirmTarget = nil
                    Task { await vm.updateStatus(item: target, action: isPause ? "pause" : "enable") }
                }
                Button("取消", role: .cancel) { vm.statusConfirmTarget = nil }
            }
        } message: {
            if let target = vm.statusConfirmTarget { Text(target.adgroupName) }
        }
        .task { await vm.load() }
    }
}

// MARK: - AdsAllAdsView

struct AdsAllAdsView: View {
    @Binding var navPath: [AdsNav]
    @StateObject private var vm: AllAdsViewModel

    init(navPath: Binding<[AdsNav]>, initialPlatform: Platform? = nil) {
        _navPath = navPath
        _vm = StateObject(wrappedValue: AllAdsViewModel(initialPlatform: initialPlatform))
    }

    var body: some View {
        VStack(spacing: 0) {
            DimensionTabRow(activeDimension: .ad) { dim in
                switch dim {
                case .account:  navPath.removeAll()
                case .campaign: navPath = [.allCampaigns(platform: vm.platformFilter)]
                case .adGroup:  navPath = [.allAdGroups(platform: vm.platformFilter)]
                case .ad:       break
                }
            }

            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty && !vm.isLoading {
                    emptyView(vm.searchText.isEmpty ? "暂无广告" : "没有匹配的广告")
                } else {
                    List {
                        ForEach(vm.items) { item in
                            AdRow(
                                item: item,
                                isUpdatingStatus: vm.updatingStatusID == item.id
                            ) { vm.statusConfirmTarget = item }
                            .swipeActions(edge: .trailing) {
                                Button { vm.statusConfirmTarget = item } label: {
                                    Label(
                                        item.status.isAdActive ? "暂停" : "开启",
                                        systemImage: item.status.isAdActive ? "pause.circle" : "play.circle"
                                    )
                                }
                                .tint(item.status.isAdActive ? .orange : .green)
                            }
                            .onAppear { if item.id == vm.items.last?.id { Task { await vm.loadMore() } } }
                        }
                        if vm.isLoadingMore { loadingMoreRow }
                    }
                    .listStyle(.plain)
                    .refreshable { await vm.refresh() }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("全部广告")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $vm.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索广告 ID 或名称")
        .safeAreaInset(edge: .top) { platformPicker($vm.platformFilter) }
        .alert("操作失败", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .confirmationDialog(
            vm.statusConfirmTarget?.status.isAdActive == true ? "确认暂停广告？" : "确认开启广告？",
            isPresented: Binding(
                get: { vm.statusConfirmTarget != nil },
                set: { if !$0 { vm.statusConfirmTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = vm.statusConfirmTarget {
                let isPause = target.status.isAdActive
                Button(isPause ? "暂停" : "开启", role: isPause ? .destructive : nil) {
                    vm.statusConfirmTarget = nil
                    Task { await vm.updateStatus(item: target, action: isPause ? "pause" : "enable") }
                }
                Button("取消", role: .cancel) { vm.statusConfirmTarget = nil }
            }
        } message: {
            if let target = vm.statusConfirmTarget { Text(target.adName) }
        }
        .task { await vm.load() }
    }
}

// MARK: - AdsAdGroupsForAccountView

struct AdsAdGroupsForAccountView: View {
    let advertiser: AdvertiserListItem
    @Binding var navPath: [AdsNav]
    @StateObject private var vm: AdGroupListViewModel

    init(advertiser: AdvertiserListItem, navPath: Binding<[AdsNav]>) {
        self.advertiser = advertiser
        _navPath = navPath
        _vm = StateObject(wrappedValue: AdGroupListViewModel(advertiserID: advertiser.id, campaignID: 0))
    }

    var body: some View {
        VStack(spacing: 0) {
            DimensionTabRow(activeDimension: .adGroup) { dim in
                switch dim {
                case .account:  navPath.removeAll()
                case .campaign: navPath.removeLast()
                case .adGroup:  break
                case .ad:       navPath.append(.adsForAccount(advertiser))
                }
            }

            BreadcrumbView(nodes: [
                BreadcrumbNode(id: 0, label: "全部账号") { navPath.removeAll() },
                BreadcrumbNode(id: 1, label: advertiser.advertiserName) { navPath.removeLast() },
                BreadcrumbNode(id: 2, label: "全部广告组", action: nil)
            ])

            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty && !vm.isLoading {
                    emptyView("暂无广告组")
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.md) {
                            ForEach(vm.items) { item in
                                AdGroupManageCard(
                                    item: item,
                                    isUpdating: vm.updatingStatusID == item.id,
                                    metrics: vm.adGroupMetrics[item.adgroupID],
                                    isLoadingMetrics: vm.isLoadingMetrics,
                                    onBudget: { vm.budgetTarget = item },
                                    onToggle: { vm.statusConfirmTarget = item },
                                    onDrill: { navPath.append(.ads(advertiser: advertiser, adgroup: item)) }
                                )
                                .onAppear { if item.id == vm.items.last?.id { Task { await vm.loadMore() } } }
                            }
                            if vm.isLoadingMore { ProgressView().padding() }
                        }
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.vertical, AppTheme.Spacing.md)
                    }
                    .refreshable { await vm.refresh() }
                    .sheet(item: $vm.budgetTarget) { item in
                        BudgetEditSheet(
                            itemName: item.adgroupName,
                            currentBudget: item.budget,
                            budgetMode: item.budgetMode
                        ) { newBudget in await vm.updateBudget(item: item, budget: newBudget) }
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(advertiser.advertiserName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("操作失败", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .confirmationDialog(
            vm.statusConfirmTarget?.status.isAdActive == true ? "确认暂停广告组？" : "确认开启广告组？",
            isPresented: Binding(get: { vm.statusConfirmTarget != nil }, set: { if !$0 { vm.statusConfirmTarget = nil } }),
            titleVisibility: .visible
        ) {
            if let target = vm.statusConfirmTarget {
                let isPause = target.status.isAdActive
                Button(isPause ? "暂停" : "开启", role: isPause ? .destructive : nil) {
                    vm.statusConfirmTarget = nil
                    Task { await vm.updateStatus(item: target, action: isPause ? "pause" : "enable") }
                }
                Button("取消", role: .cancel) { vm.statusConfirmTarget = nil }
            }
        } message: {
            if let target = vm.statusConfirmTarget { Text(target.adgroupName) }
        }
        .task { await vm.load() }
    }
}

// MARK: - AdsAdsForAccountView

struct AdsAdsForAccountView: View {
    let advertiser: AdvertiserListItem
    @StateObject private var vm: AdListViewModel

    init(advertiser: AdvertiserListItem) {
        self.advertiser = advertiser
        _vm = StateObject(wrappedValue: AdListViewModel(advertiserID: advertiser.id, adgroupID: 0))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.items.isEmpty && !vm.isLoading {
                emptyView(vm.searchText.isEmpty ? "暂无广告" : "没有匹配的广告")
            } else {
                List {
                    ForEach(vm.items) { item in
                        AdRow(
                            item: item,
                            metrics: vm.adMetrics[item.adID],
                            isUpdatingStatus: vm.updatingStatusID == item.id
                        ) { vm.statusConfirmTarget = item }
                        .swipeActions(edge: .trailing) {
                            Button { vm.statusConfirmTarget = item } label: {
                                Label(
                                    item.status.isAdActive ? "暂停" : "开启",
                                    systemImage: item.status.isAdActive ? "pause.circle" : "play.circle"
                                )
                            }
                            .tint(item.status.isAdActive ? .orange : .green)
                        }
                        .onAppear { if item.id == vm.items.last?.id { Task { await vm.loadMore() } } }
                    }
                    if vm.isLoadingMore { loadingMoreRow }
                }
                .listStyle(.plain)
                .refreshable { await vm.refresh() }
            }
        }
        .navigationTitle(advertiser.advertiserName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $vm.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索广告 ID 或名称")
        .alert("操作失败", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .confirmationDialog(
            vm.statusConfirmTarget?.status.isAdActive == true ? "确认暂停广告？" : "确认开启广告？",
            isPresented: Binding(
                get: { vm.statusConfirmTarget != nil },
                set: { if !$0 { vm.statusConfirmTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = vm.statusConfirmTarget {
                let isPause = target.status.isAdActive
                Button(isPause ? "暂停" : "开启", role: isPause ? .destructive : nil) {
                    vm.statusConfirmTarget = nil
                    Task { await vm.updateStatus(item: target, action: isPause ? "pause" : "enable") }
                }
                Button("取消", role: .cancel) { vm.statusConfirmTarget = nil }
            }
        } message: {
            if let target = vm.statusConfirmTarget { Text(target.adName) }
        }
        .task { await vm.load() }
    }
}

// MARK: - Shared platform picker helper

private func platformPicker(_ selection: Binding<Platform?>) -> some View {
    Picker("平台", selection: selection) {
        Text("全部").tag(Platform?.none)
        ForEach(Platform.allCases) { p in
            Text(p.displayName).tag(Platform?.some(p))
        }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, AppTheme.Spacing.lg)
    .padding(.vertical, AppTheme.Spacing.sm)
    .background(.bar)
}
