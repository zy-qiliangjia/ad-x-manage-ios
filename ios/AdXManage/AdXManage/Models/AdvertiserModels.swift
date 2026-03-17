import Foundation

// MARK: - 广告主列表项

struct AdvertiserListItem: Decodable, Identifiable, Hashable {
    let id: UInt64
    let platform: String
    let advertiserID: String
    let advertiserName: String
    let currency: String
    let timezone: String
    let status: UInt8
    let syncedAt: Date?
    let spend: Double
    let budget: Double
    let budgetMode: String

    enum CodingKeys: String, CodingKey {
        case id
        case platform
        case advertiserID   = "advertiser_id"
        case advertiserName = "advertiser_name"
        case currency
        case timezone
        case status
        case syncedAt       = "synced_at"
        case spend
        case budget
        case budgetMode     = "budget_mode"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UInt64.self,  forKey: .id)
        platform       = try c.decode(String.self,  forKey: .platform)
        advertiserID   = try c.decode(String.self,  forKey: .advertiserID)
        advertiserName = try c.decode(String.self,  forKey: .advertiserName)
        currency       = try c.decode(String.self,  forKey: .currency)
        timezone       = try c.decode(String.self,  forKey: .timezone)
        status         = try c.decode(UInt8.self,   forKey: .status)
        syncedAt       = try c.decodeIfPresent(Date.self, forKey: .syncedAt)
        spend          = (try? c.decodeIfPresent(Double.self, forKey: .spend)) ?? 0.0
        budget         = (try? c.decodeIfPresent(Double.self, forKey: .budget)) ?? 0.0
        budgetMode     = (try? c.decodeIfPresent(String.self, forKey: .budgetMode)) ?? ""
    }

    var platformEnum: Platform? { Platform(rawValue: platform) }
    var isActive: Bool { status == 1 }

    /// 从 CampaignItem / AdGroupItem 上下文构造轻量级广告主对象，用于导航
    init(id: UInt64, platform: String, advertiserID: String, advertiserName: String) {
        self.id             = id
        self.platform       = platform
        self.advertiserID   = advertiserID
        self.advertiserName = advertiserName
        self.currency       = ""
        self.timezone       = ""
        self.status         = 1
        self.syncedAt       = nil
        self.spend          = 0
        self.budget         = 0
        self.budgetMode     = ""
    }
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
