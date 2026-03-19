import Foundation

// MARK: - DemoData
// 体验模式使用的静态示例数据（不调用任何 API）

enum DemoData {

    // MARK: - 数据概览

    static var overview: StatsOverview {
        decode(StatsOverview.self, from: [
            "total_spend":         128_456.78,
            "total_clicks":        47_820.0,
            "total_impressions":   1_240_000.0,
            "total_conversions":   2_340.0,
            "active_advertisers":  5,
            "campaign_count":      18,
            "adgroup_count":       64
        ])!
    }

    // MARK: - 广告主列表

    static var advertisers: [AdvertiserListItem] {
        [
            makeAdvertiser(id: 1, platform: "tiktok", advertiserID: "7001234567890",
                           name: "全球时尚服饰 TikTok", currency: "USD",
                           spend: 45_200.00, budget: 60_000.00),
            makeAdvertiser(id: 2, platform: "tiktok", advertiserID: "7009876543210",
                           name: "美妆旗舰店 · TikTok", currency: "USD",
                           spend: 28_800.00, budget: 35_000.00),
            makeAdvertiser(id: 3, platform: "kwai", advertiserID: "KW_88812345",
                           name: "跨境电商旗舰 - 快手", currency: "CNY",
                           spend: 31_456.78, budget: 50_000.00),
            makeAdvertiser(id: 4, platform: "tiktok", advertiserID: "7005678901234",
                           name: "运动户外品牌 TikTok", currency: "USD",
                           spend: 15_600.00, budget: 20_000.00),
            makeAdvertiser(id: 5, platform: "kwai", advertiserID: "KW_77754321",
                           name: "家居生活馆 - 快手", currency: "CNY",
                           spend: 7_400.00, budget: 15_000.00),
        ]
    }

    // MARK: - 推广系列

    static func campaigns(for advertiserID: UInt64) -> [CampaignItem] {
        let platform = advertisers.first { $0.id == advertiserID }?.platform ?? "tiktok"
        let base = UInt64(100) + advertiserID * 10
        return [
            makeCampaign(id: base,     campaignID: "CAM_\(advertiserID)_001",
                         name: "春季大促-品牌拉新",    status: "ENABLE",
                         platform: platform, advertiserID: advertiserID,
                         budget: 10_000, spend: 6_540.20,
                         clicks: 8_200,  impressions: 312_000, conversions: 480),
            makeCampaign(id: base + 1, campaignID: "CAM_\(advertiserID)_002",
                         name: "ROI追投-老客再营销",  status: "ENABLE",
                         platform: platform, advertiserID: advertiserID,
                         budget: 8_000,  spend: 4_120.50,
                         clicks: 5_600,  impressions: 198_000, conversions: 380),
            makeCampaign(id: base + 2, campaignID: "CAM_\(advertiserID)_003",
                         name: "品牌曝光-视频素材",   status: "DISABLE",
                         platform: platform, advertiserID: advertiserID,
                         budget: 5_000,  spend: 1_200.00,
                         clicks: 2_100,  impressions: 280_000, conversions: 0),
        ]
    }

    // MARK: - 广告组

    static func adGroups(for campaignID: UInt64, advertiserID: UInt64) -> [AdGroupItem] {
        let platform = advertisers.first { $0.id == advertiserID }?.platform ?? "tiktok"
        let base = UInt64(200) + campaignID * 10
        return [
            makeAdGroup(id: base,     adgroupID: "AG_\(campaignID)_01",
                        name: "25-34岁女性-兴趣定向", campaignID: campaignID,
                        status: "ENABLE", platform: platform, advertiserID: advertiserID,
                        budget: 3_000, spend: 2_100.80, clicks: 3_200, impressions: 98_000, conversions: 180),
            makeAdGroup(id: base + 1, adgroupID: "AG_\(campaignID)_02",
                        name: "全年龄-行为再定向",    campaignID: campaignID,
                        status: "ENABLE", platform: platform, advertiserID: advertiserID,
                        budget: 2_500, spend: 1_840.40, clicks: 2_800, impressions: 76_000, conversions: 140),
            makeAdGroup(id: base + 2, adgroupID: "AG_\(campaignID)_03",
                        name: "相似受众-宽泛投放",   campaignID: campaignID,
                        status: "DISABLE", platform: platform, advertiserID: advertiserID,
                        budget: 2_000, spend: 480.20,  clicks: 890,   impressions: 45_000, conversions: 32),
        ]
    }

    // MARK: - 广告

    static func ads(for adgroupID: UInt64) -> [AdItem] {
        let base = UInt64(300) + adgroupID * 10
        return [
            makeAd(id: base,     adID: "AD_\(adgroupID)_01",
                   name: "春季新品-主图视频A", adgroupID: adgroupID, status: "ENABLE",  creativeType: "VIDEO"),
            makeAd(id: base + 1, adID: "AD_\(adgroupID)_02",
                   name: "春季新品-卖点文案B", adgroupID: adgroupID, status: "ENABLE",  creativeType: "IMAGE"),
            makeAd(id: base + 2, adID: "AD_\(adgroupID)_03",
                   name: "限时折扣-促销素材C", adgroupID: adgroupID, status: "DISABLE", creativeType: "VIDEO"),
        ]
    }

    // MARK: - Private helpers

    private static func makeAdvertiser(id: UInt64, platform: String, advertiserID: String,
                                       name: String, currency: String,
                                       spend: Double, budget: Double) -> AdvertiserListItem {
        decode(AdvertiserListItem.self, from: [
            "id": id, "platform": platform,
            "advertiser_id": advertiserID, "advertiser_name": name,
            "currency": currency, "timezone": "Asia/Shanghai",
            "status": 1, "spend": spend, "budget": budget,
            "budget_mode": "BUDGET_MODE_DAY"
        ])!
    }

    private static func makeCampaign(id: UInt64, campaignID: String, name: String,
                                     status: String, platform: String, advertiserID: UInt64,
                                     budget: Double, spend: Double,
                                     clicks: Int, impressions: Int, conversions: Int) -> CampaignItem {
        decode(CampaignItem.self, from: [
            "id": id, "campaign_id": campaignID, "campaign_name": name,
            "status": status, "budget_mode": "BUDGET_MODE_DAY",
            "budget": budget, "spend": spend, "clicks": clicks,
            "impressions": impressions, "conversions": conversions,
            "objective": "CONVERSIONS",
            "advertiser_id": advertiserID, "advertiser_name": "", "platform": platform
        ])!
    }

    private static func makeAdGroup(id: UInt64, adgroupID: String, name: String,
                                    campaignID: UInt64, status: String, platform: String,
                                    advertiserID: UInt64, budget: Double, spend: Double,
                                    clicks: Int, impressions: Int, conversions: Int) -> AdGroupItem {
        decode(AdGroupItem.self, from: [
            "id": id, "adgroup_id": adgroupID, "adgroup_name": name,
            "campaign_id": campaignID, "status": status,
            "budget_mode": "BUDGET_MODE_DAY", "budget": budget, "spend": spend,
            "bid_type": "BID_TYPE_OCPM", "bid_price": 25.0,
            "clicks": clicks, "impressions": impressions, "conversions": conversions,
            "advertiser_id": advertiserID, "advertiser_name": "", "platform": platform
        ])!
    }

    private static func makeAd(id: UInt64, adID: String, name: String,
                               adgroupID: UInt64, status: String, creativeType: String) -> AdItem {
        decode(AdItem.self, from: [
            "id": id, "ad_id": adID, "ad_name": name,
            "adgroup_id": adgroupID, "adgroup_name": "",
            "status": status, "creative_type": creativeType
        ])!
    }

    private static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
