import SwiftUI

// MARK: - AdListViewModel

@MainActor
final class AdListViewModel: ObservableObject {

    @Published var items: [AdItem]  = []
    @Published var isLoading        = false
    @Published var isLoadingMore    = false
    @Published var hasMore          = false
    @Published var error: String?   = nil

    @Published var searchText = "" { didSet { scheduleSearch() } }

    // 汇总统计（当有 adgroupID 时加载）
    @Published var dateFilter: DateRangeFilter = .last7Days {
        didSet { if adgroupID > 0 { Task { await loadSummary() } } }
    }
    @Published var summary: StatsSummary? = nil
    @Published var summaryLoading        = false

    var lastUpdatedLabel: String? { summary?.updatedTimeLabel }

    private let advertiserID: UInt64
    let adgroupID: UInt64
    private let service      = AdDetailService.shared
    private let statsService = StatsService.shared
    private var page     = 1
    private let pageSize = 20
    private var searchTask: Task<Void, Never>? = nil

    init(advertiserID: UInt64, adgroupID: UInt64 = 0) {
        self.advertiserID = advertiserID
        self.adgroupID    = adgroupID
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
    }

    func loadSummary() async {
        guard adgroupID > 0 else { return }
        summaryLoading = true
        let r = dateFilter.dateRange
        summary = try? await statsService.summary(scope: "adgroup", scopeID: adgroupID,
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
        Group {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.items.isEmpty && !vm.isLoading {
                emptyView(vm.searchText.isEmpty ? "暂无广告" : "没有匹配的广告")
            } else {
                list
            }
        }
        .searchable(text: $vm.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索广告 ID 或名称")
        .alert("错误", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .task { await vm.load() }
    }

    private var list: some View {
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

// MARK: - AdRow

struct AdRow: View {
    let item: AdItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(item.adName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                StatusBadge(status: item.status)
            }
            HStack(spacing: 12) {
                if !item.adgroupName.isEmpty {
                    Label(item.adgroupName, systemImage: "rectangle.stack")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if !item.creativeType.isEmpty {
                    Label(item.creativeType, systemImage: "photo")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(item.adID)
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
