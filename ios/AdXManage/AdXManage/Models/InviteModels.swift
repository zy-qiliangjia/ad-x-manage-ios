import Foundation

// MARK: - 邀请信息

struct InviteInfo: Decodable {
    let inviteCode:   String
    let inviteLink:   String
    let invitedCount: Int
    let earnedQuota:  Int
    let totalQuota:   Int

    enum CodingKeys: String, CodingKey {
        case inviteCode   = "invite_code"
        case inviteLink   = "invite_link"
        case invitedCount = "invited_count"
        case earnedQuota  = "earned_quota"
        case totalQuota   = "total_quota"
    }
}

// MARK: - 账号额度

struct UserQuota: Decodable {
    let totalQuota: Int
    let usedTotal:  Int
    let platforms:  [PlatformQuotaItem]

    enum CodingKeys: String, CodingKey {
        case totalQuota = "total_quota"
        case usedTotal  = "used_total"
        case platforms
    }
}

struct PlatformQuotaItem: Decodable, Identifiable {
    var id: String { platform }
    let platform: String
    let used:     Int
}
