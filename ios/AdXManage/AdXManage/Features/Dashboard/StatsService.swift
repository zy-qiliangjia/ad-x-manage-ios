import Foundation

// MARK: - StatsService

final class StatsService {

    static let shared = StatsService()
    private init() {}

    private let client = APIClient.shared

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// 近7天日期范围（startDate, endDate）
    static func last7DaysRange() -> (startDate: String, endDate: String) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: today)!
        return (dateFormatter.string(from: start), dateFormatter.string(from: today))
    }

    func overview(platform: String? = nil, startDate: String? = nil, endDate: String? = nil) async throws -> StatsOverview {
        let range = Self.last7DaysRange()
        var params: [String: String] = [
            "start_date": startDate ?? range.startDate,
            "end_date":   endDate   ?? range.endDate
        ]
        if let p = platform, !p.isEmpty { params["platform"] = p }
        return try await client.request(.stats, queryParams: params)
    }

    /// 批量拉取广告主报表指标（消耗/点击/展示/转化/CPA/日预算）
    func advertiserReport(platform: String, advertiserIDs: [String], startDate: String, endDate: String) async throws -> StatsReportResponse {
        let params: [String: String] = [
            "platform":       platform,
            "advertiser_ids": advertiserIDs.joined(separator: ","),
            "start_date":     startDate,
            "end_date":       endDate
        ]
        return try await client.request(.statsReport, queryParams: params)
    }

    /// 批量拉取广告组报表指标（消耗/点击/展示/转化/CPA）
    func adGroupReport(advertiserDBID: UInt64, adGroupIDs: [String], startDate: String, endDate: String) async throws -> AdGroupReportResponse {
        let params: [String: String] = [
            "advertiser_id": "\(advertiserDBID)",
            "adgroup_ids":   adGroupIDs.joined(separator: ","),
            "start_date":    startDate,
            "end_date":      endDate
        ]
        return try await client.request(.statsAdGroupReport, queryParams: params)
    }

    /// 按层级聚合指标：scope = "advertiser" | "campaign" | "adgroup"
    func summary(scope: String, scopeID: UInt64, dateFrom: String? = nil, dateTo: String? = nil) async throws -> StatsSummary {
        var params: [String: String] = [
            "scope":    scope,
            "scope_id": "\(scopeID)"
        ]
        if let from = dateFrom, !from.isEmpty { params["date_from"] = from }
        if let to   = dateTo,   !to.isEmpty   { params["date_to"]   = to }
        return try await client.request(.statsSummary, queryParams: params)
    }
}
