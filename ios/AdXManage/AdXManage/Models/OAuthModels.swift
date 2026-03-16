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

struct OAuthCallbackResponse: Decodable {
    let tokenID: UInt64
    let platform: String
    let advertisers: [OAuthAdvertiserItem]

    enum CodingKeys: String, CodingKey {
        case tokenID     = "token_id"
        case platform
        case advertisers
    }
}

struct OAuthAdvertiserItem: Decodable, Identifiable {
    let id: UInt64
    let advertiserID: String
    let advertiserName: String
    let currency: String
    let timezone: String
    let syncedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case advertiserID   = "advertiser_id"
        case advertiserName = "advertiser_name"
        case currency
        case timezone
        case syncedAt       = "synced_at"
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
