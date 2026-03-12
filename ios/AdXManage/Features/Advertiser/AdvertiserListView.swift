import SwiftUI

// MARK: - AdvertiserListView

struct AdvertiserListView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm       = AdvertiserListViewModel()
    @StateObject private var oauthVM  = OAuthViewModel()

    @State private var showPlatformSelection  = false
    @State private var balanceTarget: AdvertiserListItem? = nil

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("加载中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty && !vm.isLoading {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("广告账号")
            .toolbar { toolbarContent }
            // 平台筛选
            .safeAreaInset(edge: .top) { platformPicker }
            // 搜索
            .searchable(text: $vm.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索账号名称或 ID")
            // 错误提示
            .alert("请求失败", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("确定", role: .cancel) { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
            // 同步结果提示
            .sheet(item: $vm.syncResult) { result in
                SyncResultSheet(result: result.response)
            }
            // I3：平台选择
            .sheet(isPresented: $showPlatformSelection) {
                PlatformSelectionView { platform in
                    oauthVM.authorize(platform: platform)
                }
            }
            // I4：OAuth 进度
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

    // MARK: - 列表

    private var list: some View {
        List {
            ForEach(vm.items) { adv in
                NavigationLink(destination: AdvertiserDetailView(advertiser: adv)) {
                    AdvertiserRow(
                        advertiser: adv,
                        isSyncing: vm.syncingID == adv.id
                    )
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        balanceTarget = adv
                    } label: {
                        Label("余额", systemImage: "dollarsign.circle")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        Task { await vm.sync(advertiser: adv) }
                    } label: {
                        Label("同步", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .tint(.orange)
                }
                // 滚动到底部时加载更多
                .onAppear {
                    if adv.id == vm.items.last?.id {
                        Task { await vm.loadMore() }
                    }
                }
            }

            if vm.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable { await vm.refresh() }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text(vm.searchText.isEmpty ? "暂无广告账号" : "没有匹配的账号")
                    .font(.headline)
                Text(vm.searchText.isEmpty ? "点击右上角 + 添加平台账号" : "尝试修改搜索关键词")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if vm.searchText.isEmpty {
                Button {
                    showPlatformSelection = true
                } label: {
                    Label("添加平台账号", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("登出", role: .destructive) {
                Task {
                    try? await AuthService.shared.logout()
                    appState.logout()
                }
            }
            .font(.footnote)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showPlatformSelection = true } label: {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
            }
        }
    }

}

// MARK: - AdvertiserRow

private struct AdvertiserRow: View {

    let advertiser: AdvertiserListItem
    let isSyncing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：平台 badge + 账号名
            HStack(spacing: 8) {
                if let platform = advertiser.platformEnum {
                    PlatformBadge(platform: platform)
                }
                Text(advertiser.advertiserName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                statusBadge
            }
            // 第二行：账号 ID + 货币
            HStack(spacing: 12) {
                Label(advertiser.advertiserID, systemImage: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(advertiser.currency, systemImage: "coloncurrencysign.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // 第三行：同步状态
            HStack(spacing: 4) {
                if isSyncing {
                    ProgressView().scaleEffect(0.7)
                    Text("同步中…")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if let syncedAt = advertiser.syncedAt {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(syncedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("前同步")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("从未同步")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        Text(advertiser.isActive ? "正常" : "已停用")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(advertiser.isActive ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
            .foregroundStyle(advertiser.isActive ? .green : .red)
            .clipShape(Capsule())
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
                    Label(result.duration, systemImage: "timer")
                        .font(.subheadline)
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
            Text("\(count) 条")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}
