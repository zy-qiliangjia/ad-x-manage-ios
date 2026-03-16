import Foundation

// MARK: - AdDetailService
// 封装推广系列 / 广告组 / 广告的分页查询和写操作。

final class AdDetailService {

    static let shared = AdDetailService()
    private init() {}

    private let client = APIClient.shared

    // MARK: - 推广系列

    func campaigns(advertiserID: UInt64, page: Int, pageSize: Int = 20)
    async throws -> (items: [CampaignItem], pagination: APIPagination) {
        let params: [String: String] = ["page": "\(page)", "page_size": "\(pageSize)"]
        return try await client.requestPage(
            .campaigns(advertiserID: Int(advertiserID)),
            queryParams: params
        )
    }

    func updateCampaignBudget(id: UInt64, budget: Double) async throws {
        try await client.requestVoid(.campaignBudget(id: Int(id)), body: UpdateBudgetBody(budget: budget))
    }

    func updateCampaignStatus(id: UInt64, action: String) async throws {
        try await client.requestVoid(.campaignStatus(id: Int(id)), body: UpdateStatusBody(action: action))
    }

    // MARK: - 广告组

    func adGroups(advertiserID: UInt64, campaignID: UInt64 = 0, page: Int, pageSize: Int = 20)
    async throws -> (items: [AdGroupItem], pagination: APIPagination) {
        var params: [String: String] = ["page": "\(page)", "page_size": "\(pageSize)"]
        if campaignID > 0 { params["campaign_id"] = "\(campaignID)" }
        return try await client.requestPage(
            .adGroups(advertiserID: Int(advertiserID)),
            queryParams: params
        )
    }

    func updateAdGroupBudget(id: UInt64, budget: Double) async throws {
        try await client.requestVoid(.adGroupBudget(id: Int(id)), body: UpdateBudgetBody(budget: budget))
    }

    func updateAdGroupStatus(id: UInt64, action: String) async throws {
        try await client.requestVoid(.adGroupStatus(id: Int(id)), body: UpdateStatusBody(action: action))
    }

    // MARK: - 操作日志

    func operationLogs(advertiserID: UInt64, page: Int, pageSize: Int = 20)
    async throws -> (items: [OperationLogItem], pagination: APIPagination) {
        let params: [String: String] = [
            "advertiser_id": "\(advertiserID)",
            "page":          "\(page)",
            "page_size":     "\(pageSize)"
        ]
        return try await client.requestPage(.operationLogs, queryParams: params)
    }

    // MARK: - 广告

    func ads(advertiserID: UInt64, adgroupID: UInt64 = 0, keyword: String = "", page: Int, pageSize: Int = 20)
    async throws -> (items: [AdItem], pagination: APIPagination) {
        var params: [String: String] = ["page": "\(page)", "page_size": "\(pageSize)"]
        if adgroupID > 0     { params["adgroup_id"] = "\(adgroupID)" }
        if !keyword.isEmpty  { params["keyword"]    = keyword }
        return try await client.requestPage(
            .ads(advertiserID: Int(advertiserID)),
            queryParams: params
        )
    }
}
