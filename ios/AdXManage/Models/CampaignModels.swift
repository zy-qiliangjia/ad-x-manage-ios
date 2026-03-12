import SwiftUI

// MARK: - 推广系列

struct CampaignItem: Decodable, Identifiable {
    let id: UInt64
    let campaignID: String
    let campaignName: String
    let status: String
    let budgetMode: String
    let budget: Double
    let spend: Double
    let objective: String

    enum CodingKeys: String, CodingKey {
        case id
        case campaignID   = "campaign_id"
        case campaignName = "campaign_name"
        case status
        case budgetMode   = "budget_mode"
        case budget
        case spend
        case objective
    }
}

// MARK: - 广告组

struct AdGroupItem: Decodable, Identifiable {
    let id: UInt64
    let adgroupID: String
    let adgroupName: String
    let campaignID: UInt64
    let status: String
    let budgetMode: String
    let budget: Double
    let spend: Double
    let bidType: String
    let bidPrice: Double

    enum CodingKeys: String, CodingKey {
        case id
        case adgroupID   = "adgroup_id"
        case adgroupName = "adgroup_name"
        case campaignID  = "campaign_id"
        case status
        case budgetMode  = "budget_mode"
        case budget
        case spend
        case bidType     = "bid_type"
        case bidPrice    = "bid_price"
    }
}

// MARK: - 广告

struct AdItem: Decodable, Identifiable {
    let id: UInt64
    let adID: String
    let adName: String
    let adgroupID: UInt64
    let adgroupName: String
    let status: String
    let creativeType: String

    enum CodingKeys: String, CodingKey {
        case id
        case adID         = "ad_id"
        case adName       = "ad_name"
        case adgroupID    = "adgroup_id"
        case adgroupName  = "adgroup_name"
        case status
        case creativeType = "creative_type"
    }
}

// MARK: - 操作日志

/// 日志字段值：预算为 Double，状态为 String
enum LogVal: Decodable, Equatable {
    case string(String)
    case number(Double)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let d = try? c.decode(Double.self) { self = .number(d); return }
        self = .string("")
    }

    var text: String {
        switch self {
        case .string(let s): return s.adStatusLabel
        case .number(let d): return d.formatted(.number.precision(.fractionLength(2)))
        }
    }
}

struct OperationLogItem: Decodable, Identifiable {
    let id: UInt64
    let advertiserID: UInt64
    let platform: String
    let action: String        // "budget_update" | "status_update"
    let targetType: String    // "campaign" | "adgroup"
    let targetID: String
    let targetName: String
    let beforeVal: [String: LogVal]
    let afterVal: [String: LogVal]
    let result: UInt8         // 1=成功 0=失败
    let failReason: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case advertiserID = "advertiser_id"
        case platform
        case action
        case targetType  = "target_type"
        case targetID    = "target_id"
        case targetName  = "target_name"
        case beforeVal   = "before_val"
        case afterVal    = "after_val"
        case result
        case failReason  = "fail_reason"
        case createdAt   = "created_at"
    }
}

// MARK: - 修改预算 / 状态 请求体

struct UpdateBudgetBody: Encodable {
    let budget: Double
}

struct UpdateStatusBody: Encodable {
    let action: String  // "enable" | "pause"
}

// MARK: - 状态辅助

extension String {
    /// 平台原生状态 → 用户可读标签
    var adStatusLabel: String {
        switch self {
        case "ENABLE",  "ONLINE":  return "投放中"
        case "DISABLE", "OFFLINE": return "已暂停"
        case "NOT_START":          return "未开始"
        default:                   return self
        }
    }

    var adStatusColor: Color {
        switch self {
        case "ENABLE",  "ONLINE":  return .green
        case "DISABLE", "OFFLINE": return .secondary
        case "NOT_START":          return .orange
        default:                   return .secondary
        }
    }

    /// 是否当前处于"投放中"状态（用于切换按钮）
    var isAdActive: Bool {
        self == "ENABLE" || self == "ONLINE"
    }

    /// 预算模式 → 简短文案
    var budgetModeLabel: String {
        switch self {
        case "BUDGET_MODE_INFINITE": return "不限"
        case "BUDGET_MODE_DAY":      return "日预算"
        case "BUDGET_MODE_TOTAL":    return "总预算"
        default:                     return self
        }
    }
}
