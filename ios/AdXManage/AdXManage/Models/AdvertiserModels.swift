import Foundation

// MARK: - 广告主列表项

struct AdvertiserListItem: Decodable, Identifiable {
    let id: UInt64
    let platform: String
    let advertiserID: String
    let advertiserName: String
    let currency: String
    let timezone: String
    let status: UInt8
    let syncedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case platform
        case advertiserID   = "advertiser_id"
        case advertiserName = "advertiser_name"
        case currency
        case timezone
        case status
        case syncedAt       = "synced_at"
    }

    var platformEnum: Platform? { Platform(rawValue: platform) }
    var isActive: Bool { status == 1 }
}

// MARK: - 余额响应

struct BalanceResponse: Decodable {
    let advertiserID: String
    let balance: Double
    let currency: String

    enum CodingKeys: String, CodingKey {
        case advertiserID = "advertiser_id"
        case balance
        case currency
    }
}

// MARK: - 同步结果

struct SyncResponse: Decodable {
    let advertiserID: UInt64
    let campaignCount: Int
    let adGroupCount: Int
    let adCount: Int
    let duration: String
    let errors: [String]?

    enum CodingKeys: String, CodingKey {
        case advertiserID  = "advertiser_id"
        case campaignCount = "campaign_count"
        case adGroupCount  = "adgroup_count"
        case adCount       = "ad_count"
        case duration
        case errors
    }
}
