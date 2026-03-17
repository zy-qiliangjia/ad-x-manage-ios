import Foundation

final class AdvertiserService {

    static let shared = AdvertiserService()
    private init() {}

    private let client = APIClient.shared

    // MARK: - 广告主列表

    func list(
        platform: String? = nil,
        keyword: String = "",
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> (items: [AdvertiserListItem], pagination: APIPagination) {
        var params: [String: String] = [
            "page":      "\(page)",
            "page_size": "\(pageSize)",
        ]
        if let p = platform, !p.isEmpty { params["platform"] = p }
        if !keyword.isEmpty             { params["keyword"]  = keyword }

        return try await client.requestPage(.advertisers, queryParams: params)
    }

    // MARK: - 余额查询

    func balance(id: UInt64) async throws -> BalanceResponse {
        try await client.request(.advertiserBalance(id: Int(id)))
    }

    // MARK: - 手动同步

    func sync(id: UInt64) async throws -> SyncResponse {
        try await client.request(.advertiserSync(id: Int(id)))
    }

    // MARK: - 全量触发同步（登录后调用，后台异步执行，立即返回）

    func syncAll() async throws {
        try await client.requestVoid(.advertiserSyncAll)
    }

    // MARK: - 修改预算

    func updateBudget(id: UInt64, budget: Double) async throws {
        try await client.requestVoid(.advertiserBudget(id: Int(id)), body: UpdateBudgetBody(budget: budget))
    }

    // MARK: - 修改状态

    func updateStatus(id: UInt64, action: String) async throws {
        try await client.requestVoid(.advertiserStatus(id: Int(id)), body: UpdateStatusBody(action: action))
    }
}
