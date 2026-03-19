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
    case advertiserSyncAll
    case advertiserBalance(id: Int)
    case advertiserSync(id: Int)
    case advertiserBudget(id: Int)
    case advertiserStatus(id: Int)

    // ── 推广系列 ───────────────────────────────────────────
    case campaigns(advertiserID: Int)
    case campaignBudget(id: Int)
    case campaignStatus(id: Int)
    case allCampaigns

    // ── 广告组 ─────────────────────────────────────────────
    case adGroups(advertiserID: Int)
    case adGroupBudget(id: Int)
    case adGroupStatus(id: Int)
    case allAdGroups

    // ── 广告 ───────────────────────────────────────────────
    case ads(advertiserID: Int)
    case allAds
    case adStatus(id: Int)

    // ── 操作日志 ───────────────────────────────────────────
    case operationLogs

    // ── 统计概览 ───────────────────────────────────────────
    case stats
    case statsSummary
    case statsReport
    case statsAdGroupReport
    case statsCampaignReport
    case statsAdReport

    // ── 应用配置（公开接口，无需登录）───────────────────────
    case appConfig

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
        case .advertiserSyncAll:                  return "/advertisers/sync"
        case .advertiserBalance(let id):          return "/advertisers/\(id)/balance"
        case .advertiserSync(let id):             return "/advertisers/\(id)/sync"
        case .advertiserBudget(let id):           return "/advertisers/\(id)/budget"
        case .advertiserStatus(let id):           return "/advertisers/\(id)/status"

        case .campaigns(let aid):                 return "/advertisers/\(aid)/campaigns"
        case .campaignBudget(let id):             return "/campaigns/\(id)/budget"
        case .campaignStatus(let id):             return "/campaigns/\(id)/status"
        case .allCampaigns:                       return "/campaigns"

        case .adGroups(let aid):                  return "/advertisers/\(aid)/adgroups"
        case .adGroupBudget(let id):              return "/adgroups/\(id)/budget"
        case .adGroupStatus(let id):              return "/adgroups/\(id)/status"
        case .allAdGroups:                        return "/adgroups"

        case .ads(let aid):                       return "/advertisers/\(aid)/ads"
        case .allAds:                             return "/ads"
        case .adStatus(let id):                   return "/ads/\(id)/status"

        case .operationLogs:                      return "/operation-logs"

        case .stats:                              return "/stats"
        case .statsSummary:                       return "/stats/summary"
        case .statsReport:                        return "/stats/report"
        case .statsAdGroupReport:                 return "/stats/adgroup-report"
        case .statsCampaignReport:                return "/stats/campaign-report"
        case .statsAdReport:                      return "/stats/ad-report"

        case .appConfig:                          return "/config"
        }
    }

    // MARK: - HTTP Method

    var method: String {
        switch self {
        case .register, .login, .logout, .refresh,
             .oauthCallback, .advertiserSync, .advertiserSyncAll:
            return "POST"
        case .oauthRevoke:
            return "DELETE"
        case .campaignBudget, .campaignStatus,
             .adGroupBudget, .adGroupStatus,
             .advertiserBudget, .advertiserStatus,
             .adStatus:
            return "PATCH"
        default:
            return "GET"
        }
    }
}
