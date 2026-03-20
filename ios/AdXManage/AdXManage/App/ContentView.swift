import SwiftUI

// MARK: - ContentView
// 根视图：未登录时以体验模式展示 MainTabView；登录后显示完整功能。
// 体验模式：点击任意位置弹出联系客服引导弹窗。

struct ContentView: View {

    @EnvironmentObject private var appState: AppState
    @State private var showContact = false
    @State private var showLogin   = false

    var body: some View {
        VStack(spacing: 0) {
            // 未登录时在顶部显示体验模式 Banner（在 safe area 内，推开 TabView 内容）
            if !appState.isLoggedIn {
                demoBanner
            }

            MainTabView()
                // 未登录时点击任意位置弹出联系客服引导弹窗
                .overlay {
                    if !appState.isLoggedIn {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task { await appState.fetchConfig() }
                                showContact = true
                            }
                    }
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
            // 左侧：状态标签
            HStack(spacing: 5) {
                Text("预览模式")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.95, green: 0.60, blue: 0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text("登录后访问您的数据")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.45, green: 0.28, blue: 0.05))
            }

            Spacer()

            // 右侧：开通入口
            Button {
                Task { await appState.fetchConfig() }
                showContact = true
            } label: {
                HStack(spacing: 3) {
                    Text("联系开通")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.75, green: 0.40, blue: 0.00))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color(red: 1.00, green: 0.95, blue: 0.82))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.95, green: 0.82, blue: 0.50))
                .frame(height: 0.5)
        }
    }
}
