import SwiftUI

// MARK: - ContentView
// 根视图：未登录时以体验模式展示 MainTabView；登录后显示完整功能。
// 体验模式：点击任意位置弹出联系客服引导弹窗。

struct ContentView: View {

    @EnvironmentObject private var appState: AppState
    @State private var showContact = false
    @State private var showLogin   = false

    var body: some View {
        ZStack {
            MainTabView()
                // 未登录时在顶部追加体验模式 Banner
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !appState.isLoggedIn {
                        demoBanner
                    }
                }

            // 未登录时：透明覆盖层捕获所有点击，触发引导弹窗
            if !appState.isLoggedIn {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { showContact = true }
                    .ignoresSafeArea()
            }
        }
        // 联系客服引导底部弹窗
        .sheet(isPresented: $showContact) {
            ContactGuideSheet(
                isPresented: $showContact,
                config: appState.contactConfig,
                onLogin: {
                    showContact = false
                    showLogin   = true
                }
            )
        }
        // 登录页（全屏覆盖）
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
                .environmentObject(appState)
        }
        // 登录成功后自动收起所有弹窗
        .onChange(of: appState.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                showLogin   = false
                showContact = false
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isLoggedIn)
    }

    // MARK: - 体验模式 Banner

    private var demoBanner: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.Colors.warning)
                    .frame(width: 6, height: 6)
                Text("体验模式 · 示例数据")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.57, green: 0.25, blue: 0.05))
            }
            Spacer()
            Button {
                showContact = true
            } label: {
                Text("开通账号")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(AppTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.95, blue: 0.76),
                    Color(red: 0.99, green: 0.91, blue: 0.66)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}
