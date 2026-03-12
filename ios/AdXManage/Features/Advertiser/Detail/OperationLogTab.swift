import SwiftUI

// MARK: - OperationLogViewModel

@MainActor
final class OperationLogViewModel: ObservableObject {

    @Published var items: [OperationLogItem] = []
    @Published var isLoading     = false
    @Published var isLoadingMore = false
    @Published var hasMore       = false
    @Published var error: String? = nil

    private let advertiserID: UInt64
    private let service = AdDetailService.shared
    private var page     = 1
    private let pageSize = 20

    init(advertiserID: UInt64) { self.advertiserID = advertiserID }

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; page = 1
        do {
            let (fetched, pagination) = try await service.operationLogs(advertiserID: advertiserID, page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = msg(error) }
        isLoading = false
    }

    func refresh() async {
        page = 1; error = nil
        do {
            let (fetched, pagination) = try await service.operationLogs(advertiserID: advertiserID, page: 1)
            items   = fetched
            hasMore = pagination.hasMore
            page    = 2
        } catch { self.error = msg(error) }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let (fetched, pagination) = try await service.operationLogs(advertiserID: advertiserID, page: page)
            items  += fetched
            hasMore = pagination.hasMore
            page   += 1
        } catch { self.error = msg(error) }
        isLoadingMore = false
    }

    private func msg(_ e: Error) -> String {
        (e as? APIError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - OperationLogView

struct OperationLogView: View {

    let advertiser: AdvertiserListItem
    @StateObject private var vm: OperationLogViewModel

    init(advertiser: AdvertiserListItem) {
        self.advertiser = advertiser
        _vm = StateObject(wrappedValue: OperationLogViewModel(advertiserID: advertiser.id))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView("加载中…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.items.isEmpty && !vm.isLoading {
                emptyView("暂无操作记录")
            } else {
                list
            }
        }
        .alert("错误", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .task { await vm.load() }
    }

    private var list: some View {
        List {
            ForEach(vm.items) { item in
                OperationLogRow(item: item)
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

// MARK: - OperationLogRow

struct OperationLogRow: View {
    let item: OperationLogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 第一行：操作类型 + 资源类型 badge + 结果 badge
            HStack(spacing: 6) {
                Image(systemName: actionIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(actionColor)
                Text(actionLabel)
                    .font(.subheadline.weight(.semibold))
                Text(targetTypeLabel)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
                Spacer()
                resultBadge
            }
            // 第二行：资源名称
            Text(item.targetName)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
            // 第三行：变更内容
            if let change = changeText {
                Text(change)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // 第四行：失败原因
            if item.result == 0 && !item.failReason.isEmpty {
                Text(item.failReason)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            // 第五行：时间
            Text(item.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var actionLabel: String {
        switch item.action {
        case "budget_update": return "修改预算"
        case "status_update": return "切换状态"
        default:              return item.action
        }
    }

    private var actionIcon: String {
        item.action == "budget_update" ? "dollarsign.circle" : "power"
    }

    private var actionColor: Color {
        item.action == "budget_update" ? .blue : .orange
    }

    private var targetTypeLabel: String {
        switch item.targetType {
        case "campaign": return "系列"
        case "adgroup":  return "广告组"
        default:         return item.targetType
        }
    }

    private var resultBadge: some View {
        let success = item.result == 1
        return Text(success ? "成功" : "失败")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background((success ? Color.green : Color.red).opacity(0.12))
            .foregroundStyle(success ? .green : .red)
            .clipShape(Capsule())
    }

    private var changeText: String? {
        switch item.action {
        case "budget_update":
            let before = item.beforeVal["budget"]?.text ?? "—"
            let after  = item.afterVal["budget"]?.text  ?? "—"
            return "\(before) → \(after)"
        case "status_update":
            let before = item.beforeVal["status"]?.text ?? "—"
            let after  = item.afterVal["status"]?.text  ?? "—"
            return "\(before) → \(after)"
        default:
            return nil
        }
    }
}
