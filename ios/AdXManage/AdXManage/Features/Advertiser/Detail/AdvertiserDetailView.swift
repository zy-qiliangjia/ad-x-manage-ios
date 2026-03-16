import SwiftUI

// MARK: - AdvertiserDetailView
// 四 Tab 容器：推广系列 / 广告组 / 广告 / 操作记录

struct AdvertiserDetailView: View {

    let advertiser: AdvertiserListItem

    var body: some View {
        TabView {
            CampaignListView(advertiser: advertiser)
                .tabItem { Label("推广系列", systemImage: "megaphone.fill") }

            AdGroupListView(advertiser: advertiser)
                .tabItem { Label("广告组", systemImage: "rectangle.stack.fill") }

            AdListView(advertiser: advertiser)
                .tabItem { Label("广告", systemImage: "photo.fill") }

            OperationLogView(advertiser: advertiser)
                .tabItem { Label("操作记录", systemImage: "clock.arrow.circlepath") }
        }
        .navigationTitle(advertiser.advertiserName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let platform = advertiser.platformEnum {
                    PlatformBadge(platform: platform)
                }
            }
        }
    }
}
