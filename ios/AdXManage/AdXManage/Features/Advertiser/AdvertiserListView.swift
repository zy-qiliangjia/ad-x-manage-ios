import SwiftUI

// MARK: - AdvertiserListView

struct AdvertiserListView: View {

    @StateObject private var vm       = AdvertiserListViewModel()
    @StateObject private var oauthVM  = OAuthViewModel()

    @State private var showAddSheet          = false
    @State private var showPlatformSelection = false
    @State private var balanceTarget: AdvertiserListItem? = nil

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("加载中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    scrollContent
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("广告账号")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .searchable(text: $vm.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "搜索账号名称或 ID")
            .safeAreaInset(edge: .top) { platformPicker }
            .alert("请求失败", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("确定", role: .cancel) { vm.error = nil }
            } message: { Text(vm.error ?? "") }
            .sheet(item: $vm.syncResult) { result in
                SyncResultSheet(result: result.response)
            }
            // 添加账号 Bottom Sheet
            .sheet(isPresented: $showAddSheet) {
                AddAccountSheet {
                    showAddSheet = false
                    showPlatformSelection = true
                }
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
            }
            // 平台选择
            .sheet(isPresented: $showPlatformSelection) {
                PlatformSelectionView { platform in
                    oauthVM.authorize(platform: platform)
                }
            }
            // OAuth 进度
            .sheet(isPresented: $oauthVM.isPresented) {
                OAuthProgressView(vm: oauthVM) { _ in
                    Task { await vm.onOAuthSuccess() }
                }
            }
            // 余额 Sheet
            .sheet(item: $balanceTarget) { adv in
                BalanceSheetView(advertiser: adv)
            }
        }
        .task { await vm.load() }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.md) {
                if vm.items.isEmpty && !vm.isLoading {
                    emptyState
                        .padding(.top, 60)
                } else {
                    ForEach(vm.items) { adv in
                        NavigationLink(destination: AdvertiserDetailView(advertiser: adv)) {
                            AdvertiserCardView(
                                advertiser: adv,
                                isSyncing: vm.syncingID == adv.id
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                balanceTarget = adv
                            } label: {
                                Label("查看余额", systemImage: "dollarsign.circle")
                            }
                            Button {
                                Task { await vm.sync(advertiser: adv) }
                            } label: {
                                Label("手动同步", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        // 保留左滑/右滑（包装在 List 外时用 swipeActions 需要 List，改用 onLongPress 替代）
                        .onAppear {
                            if adv.id == vm.items.last?.id {
                                Task { await vm.loadMore() }
                            }
                        }
                    }

                    if vm.isLoadingMore {
                        ProgressView().padding()
                    }
                }

                // 虚线添加按钮
                addAccountButton
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.top, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .refreshable { await vm.refresh() }
    }

    // MARK: - 虚线添加按钮

    private var addAccountButton: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.Colors.primary)
                Text("授权添加新广告账号")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                    .stroke(AppTheme.Colors.border, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 平台筛选条

    private var platformPicker: some View {
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

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
            VStack(spacing: 6) {
                Text(vm.searchText.isEmpty ? "暂无广告账号" : "没有匹配的账号")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(vm.searchText.isEmpty ? "点击右上角 + 或下方按钮添加平台账号" : "尝试修改搜索关键词")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - AdvertiserCardView

struct AdvertiserCardView: View {
    let advertiser: AdvertiserListItem
    let isSyncing: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：头像 + 账号信息
            HStack(spacing: AppTheme.Spacing.md) {
                // TikTok 头像
                platformAvatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(advertiser.advertiserName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text("ID: \(advertiser.advertiserID.truncatedID)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    AdvertiserStatusBadgeView(AdvertiserStatus(isActive: advertiser.isActive))
                        .padding(.top, 2)
                }

                Spacer()

                // 同步状态
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if advertiser.syncedAt != nil {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
                        Text("已同步")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
                    }
                }
            }
            .padding(AppTheme.Spacing.lg)

            // 底部：三列数据行
            Divider()
                .padding(.horizontal, AppTheme.Spacing.lg)

            HStack(spacing: 0) {
                metricCell(label: "本周消耗", value: "--")
                Divider().frame(height: 32)
                metricCell(label: "推广系列", value: "--")
                Divider().frame(height: 32)
                metricCell(label: "货币", value: advertiser.currency)
            }
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
    }

    private var platformAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.Colors.tiktokDark, Color(red: 0.2, green: 0.2, blue: 0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
            Text(advertiser.platformEnum == .kwai ? "K" : "T")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}

// MARK: - AddAccountSheet

private struct AddAccountSheet: View {
    let onSelectTikTok: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, AppTheme.Spacing.md)

            Text("授权添加广告账号")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            // TikTok 选项
            Button(action: onSelectTikTok) {
                HStack(spacing: AppTheme.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.tiktokDark,
                                             Color(red: 0.2, green: 0.2, blue: 0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        Text("T")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TikTok 广告")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("通过 TikTok For Business 授权绑定广告账号")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
                }
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                        .stroke(AppTheme.Colors.border, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer()
        }
    }
}

// MARK: - SyncResultSheet

private struct SyncResultSheet: View {
    let result: SyncResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("同步结果") {
                    resultRow("推广系列", count: result.campaignCount, icon: "megaphone.fill")
                    resultRow("广告组",   count: result.adGroupCount,  icon: "rectangle.stack.fill")
                    resultRow("广告",     count: result.adCount,       icon: "photo.fill")
                }
                Section("耗时") {
                    Label(result.duration, systemImage: "timer").font(.subheadline)
                }
                if let errors = result.errors, !errors.isEmpty {
                    Section("警告") {
                        ForEach(errors, id: \.self) { err in
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("同步完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func resultRow(_ label: String, count: Int, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text("\(count) 条").foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

// MARK: - String Helper

private extension String {
    /// 末 6 位加 `…` 前缀；6 位及以下完整显示
    var truncatedID: String {
        count > 6 ? "…\(suffix(6))" : self
    }
}
