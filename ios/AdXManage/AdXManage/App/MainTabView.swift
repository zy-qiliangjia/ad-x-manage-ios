import SwiftUI

// MARK: - MainTabView
// 登录后的主容器：4 Tab 底部导航 + 全局 Toast 注入

struct MainTabView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var toast = ToastManager()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("数据", systemImage: "chart.bar.xaxis") }
                .tag(0)

            AdvertiserListView()
                .tabItem { Label("账号", systemImage: "person.2") }
                .tag(1)

            AdsManageView()
                .tabItem { Label("广告", systemImage: "rectangle.stack") }
                .tag(2)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(AppTheme.Colors.primary)
        .environmentObject(toast)
        .toastOverlay(toast)
        .onChange(of: appState.isLoggedIn) { _, isLoggedIn in
            if !isLoggedIn { selectedTab = 0 }
        }
    }
}
