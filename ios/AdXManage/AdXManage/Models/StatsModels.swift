import Foundation

// MARK: - 数据概览

struct StatsOverview: Decodable {
    let totalSpend: Double
    let activeAdvertisers: Int
    let campaignCount: Int
    let adGroupCount: Int

    enum CodingKeys: String, CodingKey {
        case totalSpend        = "total_spend"
        case activeAdvertisers = "active_advertisers"
        case campaignCount     = "campaign_count"
        case adGroupCount      = "adgroup_count"
    }
}
