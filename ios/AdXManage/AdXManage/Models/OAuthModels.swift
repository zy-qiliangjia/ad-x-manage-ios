import Foundation

// MARK: - 获取授权 URL

struct OAuthURLResponse: Decodable {
    let url: String
    let state: String
}

// MARK: - 回调（iOS → 后端）

struct OAuthCallbackRequest: Encodable {
    let code: String
    let state: String
}

// MARK: - 回调响应（后端 → iOS）
// 此阶段返回平台全量广告主（含已存库标记）和额度信息，不保存广告主。
// 用户在 iOS 端选择后调用 Confirm 接口才正式保存。

struct OAuthCallbackResponse: Decodable {
    let tokenID: UInt64
    let platform: String
    let advertisers: [OAuthAdvertiserItem]
    let quota: Int
    let usedQuota: Int
    let remaining: Int

    enum CodingKeys: String, CodingKey {
        case tokenID     = "token_id"
        case platform
        case advertisers
        case quota
        case usedQuota   = "used_quota"
        case remaining
    }
}

struct OAuthAdvertiserItem: Decodable, Identifiable {
    /// 平台广告主 ID（唯一，用作 SwiftUI Identifiable key）
    let advertiserID: String
    let advertiserName: String
    let currency: String
    let timezone: String
    let syncedAt: Date?
    let isExisting: Bool  // true = 已存库，UI 需锁定

    /// Identifiable 使用平台广告主 ID，避免未入库时 DB id=0 引发的重复 key 问题
    var id: String { advertiserID }

    enum CodingKeys: String, CodingKey {
        case advertiserID   = "advertiser_id"
        case advertiserName = "advertiser_name"
        case currency
        case timezone
        case syncedAt       = "synced_at"
        case isExisting     = "is_existing"
    }
}

// MARK: - 确认选择（iOS → 后端）

struct OAuthConfirmRequest: Encodable {
    let tokenID: UInt64
    let advertiserIDs: [String]

    enum CodingKeys: String, CodingKey {
        case tokenID      = "token_id"
        case advertiserIDs = "advertiser_ids"
    }
}

struct OAuthConfirmResponse: Decodable {
    let tokenID: UInt64
    let platform: String
    let advertisers: [OAuthAdvertiserItem]

    enum CodingKeys: String, CodingKey {
        case tokenID     = "token_id"
        case platform
        case advertisers
    }
}

// MARK: - 客户端 OAuth 专用错误

enum OAuthError: Error, LocalizedError {
    case userCancelled
    case invalidCallbackURL
    case missingCodeOrState
    case sessionError(Error)

    var errorDescription: String? {
        switch self {
        case .userCancelled:       return "用户取消了授权"
        case .invalidCallbackURL:  return "无效的回调 URL"
        case .missingCodeOrState:  return "平台未返回授权码，请重试"
        case .sessionError(let e): return "授权会话错误：\(e.localizedDescription)"
        }
    }
}
