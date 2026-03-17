import SwiftUI

// MARK: - MainTabView
// 登录后的主容器：4 Tab 底部导航 + 全局 Toast 注入

struct MainTabView: View {

    @StateObject private var toast = ToastManager()

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("数据", systemImage: "chart.bar.xaxis") }

            AdvertiserListView()
                .tabItem { Label("账号", systemImage: "person.2") }

            AdsManageView()
                .tabItem { Label("广告", systemImage: "rectangle.stack") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(AppTheme.Colors.primary)
        .environmentObject(toast)
        .toastOverlay(toast)
    }
}
