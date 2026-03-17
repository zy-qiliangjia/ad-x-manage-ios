import SwiftUI

// MARK: - 导航目标

enum AdsNav: Hashable {
    case campaigns(AdvertiserListItem)
    case adGroups(advertiser: AdvertiserListItem, campaign: CampaignItem)
    case ads(advertiser: AdvertiserListItem, adgroup: AdGroupItem)
    // 全量视图
    case allCampaigns
    case allAdGroups
    case allAds
    // 账号作用域跨层跳转
    case adGroupsForAccount(AdvertiserListItem)
    case adsForAccount(AdvertiserListItem)
}

// MARK: - AdsManageView

struct AdsManageView: View {

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
                    case .campaign: navPath = [.allCampaigns]
                    case .adGroup:  navPath = [.allAdGroups]
                    case .ad:       navPath = [.allAds]
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
                case .allCampaigns:
                    AdsAllCampaignsView(navPath: $navPath)
                case .allAdGroups:
                    AdsAllAdGroupsView(navPath: $navPath)
                case .allAds:
                    AdsAllAdsView(navPath: $navPath)
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
                Picker("平台", selection: $vm.platformFilter) {
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
                    // 汇总卡片
                    AdsSummaryCardView(
                        scopeLabel: "全部账号",
                        spend: 0, clicks: 0, impressions: 0, conversions: 0
                    )

                    ForEach(vm.items) { adv in
                        AdsAccountCardView(
                            advertiser: adv,
                            isUpdating: vm.updatingStatusID == adv.id,
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

    private let service  = AdvertiserService.shared
    private var page     = 1
    private let pageSize = 20
    private var searchTask: Task<Void, Never>? = nil

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
    }

    func refresh() async {
        page = 1; error = nil
        do {
            let (fetched, pagination) = try await fetch(page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = msg(error) }
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
    }

    func updateBudget(item: AdvertiserListItem, budget: Double) async {
        do {
            try await service.updateBudget(id: item.id, budget: budget)
            await refresh()
        } catch {
            self.error = msg(error)
        }
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

    private func fetch(page: Int) async throws -> ([AdvertiserListItem], APIPagination) {
        try await service.list(platform: platformFilter?.rawValue, keyword: searchText,
                               page: page, pageSize: pageSize)
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    private func msg(_ e: Error) -> String {
        (e as? APIError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - AdsAccountCardView (账号层级卡片)

private struct AdsAccountCardView: View {
    let advertiser: AdvertiserListItem
    let isUpdating: Bool
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

            // 中部：消耗 + 预算指标行
            HStack {
                metricCell(label: "消耗", value: advertiser.spend.statFormatted)
                metricCell(
                    label: advertiser.budgetMode.budgetModeLabel,
                    value: advertiser.budgetMode == "BUDGET_MODE_INFINITE" || advertiser.budget <= 0
                        ? "不限" : "¥\(Int(advertiser.budget))"
                )
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)

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

    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.trailing, AppTheme.Spacing.lg)
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
                                spend: vm.items.reduce(0) { $0 + $1.spend },
                                clicks: 0, impressions: 0, conversions: 0
                            )

                            ForEach(vm.items) { item in
                                CampaignManageCard(
                                    item: item,
                                    isUpdating: vm.updatingStatusID == item.id,
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
                                spend: vm.items.reduce(0) { $0 + $1.spend },
                                clicks: 0, impressions: 0, conversions: 0
                            )

                            ForEach(vm.items) { item in
                                AdGroupManageCard(
                                    item: item,
                                    isUpdating: vm.updatingStatusID == item.id,
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
        Group {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.items.isEmpty && !vm.isLoading {
                emptyView(vm.searchText.isEmpty ? "暂无广告" : "没有匹配的广告")
            } else {
                List {
                    ForEach(vm.items) { item in
                        AdRow(item: item)
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
        .navigationTitle(adgroup.adgroupName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $vm.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索广告 ID 或名称")
        .alert("错误", isPresented: Binding(
            get: { vm.error != nil }, set: { if !$0 { vm.error = nil } }
        )) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .task { await vm.load() }
    }
}

// MARK: - CampaignManageCard

private struct CampaignManageCard: View {
    let item: CampaignItem
    let isUpdating: Bool
    let onBudget: () -> Void
    let onToggle: () -> Void
    let onDrill: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：名称 + 状态开关
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
                    // Toggle 开关
                    Toggle("", isOn: .constant(item.status.isAdActive))
                        .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.success))
                        .labelsHidden()
                        .scaleEffect(0.85)
                        .onTapGesture { onToggle() }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.md)

            // 消耗 + 预算行
            HStack {
                metricCell(label: "消耗", value: item.spend.statFormatted)
                metricCell(label: item.budgetMode.budgetModeLabel,
                           value: item.budgetMode == "BUDGET_MODE_INFINITE"
                               ? "不限" : "¥\(Int(item.budget))")
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)

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

    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.trailing, AppTheme.Spacing.lg)
    }
}

// MARK: - AdGroupManageCard

private struct AdGroupManageCard: View {
    let item: AdGroupItem
    let isUpdating: Bool
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
                    Toggle("", isOn: .constant(item.status.isAdActive))
                        .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.success))
                        .labelsHidden()
                        .scaleEffect(0.85)
                        .onTapGesture { onToggle() }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.md)

            HStack {
                metricCell(label: "消耗", value: item.spend.statFormatted)
                metricCell(label: item.budgetMode.budgetModeLabel,
                           value: item.budgetMode == "BUDGET_MODE_INFINITE"
                               ? "不限" : "¥\(Int(item.budget))")
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)

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

    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.Colors.textPrimary)
            Text(label).font(.system(size: 10)).foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.trailing, AppTheme.Spacing.lg)
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
    @Published var platformFilter: Platform? = nil { didSet { Task { await refresh() } } }

    private let service  = AdDetailService.shared
    private var page     = 1
    private let pageSize = 20

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; page = 1
        do {
            let (fetched, p) = try await service.allCampaigns(platform: platformFilter?.rawValue, page: 1, pageSize: pageSize)
            items = fetched; hasMore = p.hasMore; page = 2
        } catch { self.error = msg(error) }
        isLoading = false
    }

    func refresh() async {
        page = 1; error = nil
        do {
            let (fetched, p) = try await service.allCampaigns(platform: platformFilter?.rawValue, page: 1, pageSize: pageSize)
            items = fetched; hasMore = p.hasMore; page = 2
        } catch { self.error = msg(error) }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let (fetched, p) = try await service.allCampaigns(platform: platformFilter?.rawValue, page: page, pageSize: pageSize)
            items += fetched; hasMore = p.hasMore; page += 1
        } catch { self.error = msg(error) }
        isLoadingMore = false
    }

    private func msg(_ e: Error) -> String { (e as? APIError)?.errorDescription ?? e.localizedDescription }
}

// MARK: - AllAdGroupsViewModel

@MainActor
final class AllAdGroupsViewModel: ObservableObject {
    @Published var items: [AdGroupItem] = []
    @Published var isLoading     = false
    @Published var isLoadingMore = false
    @Published var hasMore       = false
    @Published var error: String? = nil
    @Published var platformFilter: Platform? = nil { didSet { Task { await refresh() } } }

    private let service  = AdDetailService.shared
    private var page     = 1
    private let pageSize = 20

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

    private func msg(_ e: Error) -> String { (e as? APIError)?.errorDescription ?? e.localizedDescription }
}

// MARK: - AllAdsViewModel

@MainActor
final class AllAdsViewModel: ObservableObject {
    @Published var items: [AdItem] = []
    @Published var isLoading     = false
    @Published var isLoadingMore = false
    @Published var hasMore       = false
    @Published var error: String? = nil
    @Published var platformFilter: Platform? = nil { didSet { Task { await refresh() } } }
    @Published var searchText    = "" { didSet { scheduleSearch() } }

    private let service    = AdDetailService.shared
    private var page       = 1
    private let pageSize   = 20
    private var searchTask: Task<Void, Never>? = nil

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

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    private func msg(_ e: Error) -> String { (e as? APIError)?.errorDescription ?? e.localizedDescription }
}

// MARK: - AdsAllCampaignsView

struct AdsAllCampaignsView: View {
    @Binding var navPath: [AdsNav]
    @StateObject private var vm = AllCampaignsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            DimensionTabRow(activeDimension: .campaign) { dim in
                switch dim {
                case .account:  navPath.removeAll()
                case .campaign: break
                case .adGroup:  navPath = [.allAdGroups]
                case .ad:       navPath = [.allAds]
                }
            }

            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty && !vm.isLoading {
                    emptyView("暂无推广系列")
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.md) {
                            ForEach(vm.items) { item in
                                Button {
                                    let adv = AdvertiserListItem(
                                        id: item.advertiserID, platform: item.platform,
                                        advertiserID: String(item.advertiserID),
                                        advertiserName: item.advertiserName)
                                    navPath.append(.adGroups(advertiser: adv, campaign: item))
                                } label: {
                                    CampaignReadOnlyCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .onAppear { if item.id == vm.items.last?.id { Task { await vm.loadMore() } } }
                            }
                            if vm.isLoadingMore { ProgressView().padding() }
                        }
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.vertical, AppTheme.Spacing.md)
                    }
                    .refreshable { await vm.refresh() }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("全部推广系列")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) { platformPicker($vm.platformFilter) }
        .alert("加载失败", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .task { await vm.load() }
    }
}

// MARK: - AdsAllAdGroupsView

struct AdsAllAdGroupsView: View {
    @Binding var navPath: [AdsNav]
    @StateObject private var vm = AllAdGroupsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            DimensionTabRow(activeDimension: .adGroup) { dim in
                switch dim {
                case .account:  navPath.removeAll()
                case .campaign: navPath = [.allCampaigns]
                case .adGroup:  break
                case .ad:       navPath = [.allAds]
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
                            ForEach(vm.items) { item in
                                Button {
                                    let adv = AdvertiserListItem(
                                        id: item.advertiserID, platform: item.platform,
                                        advertiserID: String(item.advertiserID),
                                        advertiserName: item.advertiserName)
                                    navPath.append(.ads(advertiser: adv, adgroup: item))
                                } label: {
                                    AdGroupReadOnlyCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .onAppear { if item.id == vm.items.last?.id { Task { await vm.loadMore() } } }
                            }
                            if vm.isLoadingMore { ProgressView().padding() }
                        }
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.vertical, AppTheme.Spacing.md)
                    }
                    .refreshable { await vm.refresh() }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("全部广告组")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) { platformPicker($vm.platformFilter) }
        .alert("加载失败", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .task { await vm.load() }
    }
}

// MARK: - AdsAllAdsView

struct AdsAllAdsView: View {
    @Binding var navPath: [AdsNav]
    @StateObject private var vm = AllAdsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            DimensionTabRow(activeDimension: .ad) { dim in
                switch dim {
                case .account:  navPath.removeAll()
                case .campaign: navPath = [.allCampaigns]
                case .adGroup:  navPath = [.allAdGroups]
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
                            AdRow(item: item)
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
        .alert("加载失败", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
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
                        AdRow(item: item)
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
        .alert("错误", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .task { await vm.load() }
    }
}

// MARK: - Read-only cards (全量视图用)

private struct CampaignReadOnlyCard: View {
    let item: CampaignItem

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.campaignName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                if !item.advertiserName.isEmpty {
                    Text(item.advertiserName)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: item.status)
                Text(item.spend.statFormatted)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.4))
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
        .contentShape(Rectangle())
    }
}

private struct AdGroupReadOnlyCard: View {
    let item: AdGroupItem

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.adgroupName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                if !item.advertiserName.isEmpty {
                    Text(item.advertiserName)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: item.status)
                Text(item.spend.statFormatted)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.4))
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
        .contentShape(Rectangle())
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
