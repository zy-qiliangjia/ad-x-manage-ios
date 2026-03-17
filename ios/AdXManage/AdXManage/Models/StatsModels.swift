import Foundation

// MARK: - 汇总统计（按层级聚合）

struct StatsSummary: Decodable {
    let spend: Double
    let clicks: Int
    let impressions: Int
    let conversions: Int
    let lastUpdatedAt: String?   // ISO 8601 string from server

    enum CodingKeys: String, CodingKey {
        case spend
        case clicks
        case impressions
        case conversions
        case lastUpdatedAt = "last_updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        spend         = (try? c.decodeIfPresent(Double.self, forKey: .spend))       ?? 0
        clicks        = (try? c.decodeIfPresent(Int.self,    forKey: .clicks))      ?? 0
        impressions   = (try? c.decodeIfPresent(Int.self,    forKey: .impressions)) ?? 0
        conversions   = (try? c.decodeIfPresent(Int.self,    forKey: .conversions)) ?? 0
        lastUpdatedAt = try? c.decodeIfPresent(String.self,  forKey: .lastUpdatedAt)
    }

    /// "HH:mm" 本地时间，用于 ToolbarItem 更新时间展示
    var updatedTimeLabel: String? {
        guard let s = lastUpdatedAt else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: s) ?? {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s)
        }()
        guard let date else { return nil }
        let hm = DateFormatter()
        hm.dateFormat = "HH:mm"
        return hm.string(from: date)
    }
}

// MARK: - 数据概览

struct StatsOverview: Decodable {
    let totalSpend: Double
    let totalClicks: Double
    let totalImpressions: Double
    let totalConversions: Double
    let activeAdvertisers: Int
    let campaignCount: Int
    let adGroupCount: Int

    enum CodingKeys: String, CodingKey {
        case totalSpend        = "total_spend"
        case totalClicks       = "total_clicks"
        case totalImpressions  = "total_impressions"
        case totalConversions  = "total_conversions"
        case activeAdvertisers = "active_advertisers"
        case campaignCount     = "campaign_count"
        case adGroupCount      = "adgroup_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalSpend        = (try? c.decodeIfPresent(Double.self, forKey: .totalSpend))       ?? 0
        totalClicks       = (try? c.decodeIfPresent(Double.self, forKey: .totalClicks))      ?? 0
        totalImpressions  = (try? c.decodeIfPresent(Double.self, forKey: .totalImpressions)) ?? 0
        totalConversions  = (try? c.decodeIfPresent(Double.self, forKey: .totalConversions)) ?? 0
        activeAdvertisers = (try? c.decodeIfPresent(Int.self,    forKey: .activeAdvertisers)) ?? 0
        campaignCount     = (try? c.decodeIfPresent(Int.self,    forKey: .campaignCount))    ?? 0
        adGroupCount      = (try? c.decodeIfPresent(Int.self,    forKey: .adGroupCount))     ?? 0
    }
}
