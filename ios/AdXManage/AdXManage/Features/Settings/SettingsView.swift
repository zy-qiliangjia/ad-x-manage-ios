import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    @EnvironmentObject private var appState: AppState
    @State private var showPlatformSelection = false
    @State private var showLogoutAlert       = false
    @StateObject private var oauthVM = OAuthViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    // 渐变头像 Banner
                    profileBanner

                    // 分组设置
                    VStack(spacing: AppTheme.Spacing.md) {
                        settingsGroup(title: "账号管理", items: [
                            SettingsRow(
                                icon: "person.crop.rectangle.stack.fill",
                                iconBg: AppTheme.Colors.primary,
                                title: "广告账号管理",
                                subtitle: "查看和管理已绑定的广告账号",
                                action: nil,
                                isDestructive: false
                            )
                        ])

                        settingsGroup(title: "平台授权", items: [
                            SettingsRow(
                                icon: "link.badge.plus",
                                iconBg: AppTheme.Colors.tiktokRed,
                                title: "添加平台授权",
                                subtitle: "绑定 TikTok 广告账号",
                                action: { showPlatformSelection = true },
                                isDestructive: false
                            )
                        ])

                        settingsGroup(title: "关于", items: [
                            SettingsRow(
                                icon: "info.circle.fill",
                                iconBg: Color(red: 0.06, green: 0.67, blue: 0.67),
                                title: "版本",
                                subtitle: versionString,
                                action: nil,
                                isDestructive: false
                            )
                        ])

                        // 退出登录
                        Button {
                            showLogoutAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 14))
                                Text("退出登录")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                            }
                            .foregroundStyle(AppTheme.Colors.danger)
                            .padding(.vertical, AppTheme.Spacing.lg)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                            .cardShadow()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, AppTheme.Spacing.xl)
                    }
                    .padding(.bottom, AppTheme.Spacing.xl)
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("退出", role: .destructive) {
                    Task {
                        try? await AuthService.shared.logout()
                        appState.logout()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定要退出登录吗？")
            }
            .sheet(isPresented: $showPlatformSelection) {
                PlatformSelectionView { platform in
                    oauthVM.authorize(platform: platform)
                }
            }
            .sheet(isPresented: $oauthVM.isPresented) {
                OAuthProgressView(vm: oauthVM) { _ in }
            }
        }
    }

    // MARK: - 渐变头像 Banner

    private var profileBanner: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // 头像
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.pill)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, Color(red: 0.49, green: 0.23, blue: 0.93)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                Text(avatarLetter)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(appState.userEmail)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppTheme.Spacing.xl)
        .padding(.bottom, AppTheme.Spacing.lg)
    }

    // MARK: - 分组

    private func settingsGroup(title: String, items: [SettingsRow]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.xl + AppTheme.Spacing.sm)

            VStack(spacing: 0) {
                ForEach(items) { row in
                    settingsRowView(row)
                }
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
            .cardShadow()
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }

    @ViewBuilder
    private func settingsRowView(_ row: SettingsRow) -> some View {
        if let action = row.action {
            Button(action: action) {
                rowContent(row)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(row)
        }
    }

    private func rowContent(_ row: SettingsRow) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .fill(row.iconBg)
                    .frame(width: 34, height: 34)
                Image(systemName: row.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(row.isDestructive ? AppTheme.Colors.danger : AppTheme.Colors.textPrimary)
                if let sub = row.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            if row.action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.4))
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
    }

    // MARK: - Helpers

    private var avatarLetter: String {
        String(appState.userEmail.prefix(1).uppercased())
    }

    private var displayName: String {
        let prefix = String(appState.userEmail.split(separator: "@").first ?? "User")
        return prefix.isEmpty ? "用户" : prefix
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) (\(build))"
    }
}

// MARK: - SettingsRow Model

private struct SettingsRow: Identifiable {
    let id = UUID()
    let icon: String
    let iconBg: Color
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let isDestructive: Bool
}
