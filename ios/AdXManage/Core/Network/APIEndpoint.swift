import Foundation

// MARK: - API 端点定义

enum APIEndpoint {

    // ── Auth ───────────────────────────────────────────────
    case register
    case login
    case logout
    case refresh

    // ── OAuth ──────────────────────────────────────────────
    case oauthURL(platform: String)
    case oauthCallback(platform: String)
    case oauthRevoke(platform: String, tokenID: Int)

    // ── 广告主 ─────────────────────────────────────────────
    case advertisers
    case advertiserBalance(id: Int)
    case advertiserSync(id: Int)

    // ── 推广系列 ───────────────────────────────────────────
    case campaigns(advertiserID: Int)
    case campaignBudget(id: Int)
    case campaignStatus(id: Int)

    // ── 广告组 ─────────────────────────────────────────────
    case adGroups(advertiserID: Int)
    case adGroupBudget(id: Int)
    case adGroupStatus(id: Int)

    // ── 广告 ───────────────────────────────────────────────
    case ads(advertiserID: Int)

    // ── 操作日志 ───────────────────────────────────────────
    case operationLogs

    // MARK: - Path

    var path: String {
        switch self {
        case .register:                           return "/auth/register"
        case .login:                              return "/auth/login"
        case .logout:                             return "/auth/logout"
        case .refresh:                            return "/auth/refresh"

        case .oauthURL(let p):                    return "/oauth/\(p)/url"
        case .oauthCallback(let p):               return "/oauth/\(p)/callback"
        case .oauthRevoke(let p, let id):         return "/oauth/\(p)/\(id)"

        case .advertisers:                        return "/advertisers"
        case .advertiserBalance(let id):          return "/advertisers/\(id)/balance"
        case .advertiserSync(let id):             return "/advertisers/\(id)/sync"

        case .campaigns(let aid):                 return "/advertisers/\(aid)/campaigns"
        case .campaignBudget(let id):             return "/campaigns/\(id)/budget"
        case .campaignStatus(let id):             return "/campaigns/\(id)/status"

        case .adGroups(let aid):                  return "/advertisers/\(aid)/adgroups"
        case .adGroupBudget(let id):              return "/adgroups/\(id)/budget"
        case .adGroupStatus(let id):              return "/adgroups/\(id)/status"

        case .ads(let aid):                       return "/advertisers/\(aid)/ads"

        case .operationLogs:                      return "/operation-logs"
        }
    }

    // MARK: - HTTP Method

    var method: String {
        switch self {
        case .register, .login, .logout, .refresh,
             .oauthCallback, .advertiserSync:
            return "POST"
        case .oauthRevoke:
            return "DELETE"
        case .campaignBudget, .campaignStatus,
             .adGroupBudget, .adGroupStatus:
            return "PATCH"
        default:
            return "GET"
        }
    }
}
