import SwiftUI

// MARK: - InviteFriendsView

struct InviteFriendsView: View {

    @State private var info:         InviteInfo? = nil
    @State private var isLoading                 = false
    @State private var errorMessage: String?     = nil
    @State private var copyToast:    String?     = nil

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    if isLoading {
                        loadingState
                    } else if let msg = errorMessage {
                        errorState(msg)
                    } else if let info = info {
                        heroBanner
                        inviteCodeCard(info)
                        inviteLinkCard(info)
                        statsRow(info)
                        posterButton
                        quotaHint(info)
                    } else {
                        loadingState
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.bottom, AppTheme.Spacing.xl)
            }

            // 复制成功 Toast
            if let toast = copyToast {
                VStack {
                    Spacer()
                    toastView(toast)
                        .padding(.bottom, 40)
                }
                .ignoresSafeArea()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(999)
            }
        }
        .navigationTitle("邀请好友")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Hero

    private var heroBanner: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Colors.primary,
                    Color(red: 0.49, green: 0.23, blue: 0.93),
                    Color(red: 0.78, green: 0.20, blue: 0.80)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))

            // 装饰圆圈
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 180)
                .offset(x: 90, y: -30)
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 120)
                .offset(x: -60, y: 40)

            VStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }

                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("邀请好友，扩展账号额度")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("每成功邀请 1 位新用户注册 AdPilot\n你和好友各获得 +5 个广告账号额度")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            .padding(.vertical, AppTheme.Spacing.xl + AppTheme.Spacing.md)
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 16, x: 0, y: 8)
    }

    // MARK: - 邀请码卡片

    private func inviteCodeCard(_ info: InviteInfo) -> some View {
        infoCard(title: "我的邀请码", icon: "number.square.fill", iconColor: AppTheme.Colors.primary) {
            HStack(spacing: AppTheme.Spacing.md) {
                Text(info.inviteCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .tracking(4)

                Spacer()

                copyButton(label: "复制", value: info.inviteCode, toast: "邀请码已复制")
            }
        }
    }

    // MARK: - 邀请链接卡片

    private func inviteLinkCard(_ info: InviteInfo) -> some View {
        infoCard(title: "App 下载链接", icon: "link.circle.fill", iconColor: Color(red: 0.06, green: 0.67, blue: 0.67)) {
            HStack(spacing: AppTheme.Spacing.md) {
                Text(info.inviteLink)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                copyButton(label: "复制", value: info.inviteLink, toast: "链接已复制")
            }
        }
    }

    // MARK: - 统计行

    private func statsRow(_ info: InviteInfo) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            statCell(value: "\(info.invitedCount)", label: "已邀请")
            divider
            statCell(value: "+\(info.earnedQuota)", label: "获得额度", valueColor: AppTheme.Colors.success)
            divider
            statCell(value: "\(info.totalQuota)", label: "当前总额度", valueColor: AppTheme.Colors.primary)
        }
        .padding(.vertical, AppTheme.Spacing.lg)
        .padding(.horizontal, AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
    }

    private func statCell(value: String, label: String, valueColor: Color = AppTheme.Colors.textPrimary) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.Colors.border)
            .frame(width: 1, height: 36)
    }

    // MARK: - 生成海报按钮

    private var posterButton: some View {
        Button {
            showToast("功能即将上线")
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16))
                Text("生成邀请海报")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(AppTheme.Colors.primary)
            .padding(.vertical, AppTheme.Spacing.lg)
            .background(AppTheme.Colors.primaryBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(AppTheme.Colors.primary.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 额度规则提示

    private func quotaHint(_ info: InviteInfo) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text("额度说明")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                hintLine("• 新用户注册默认获得 5 个账号额度")
                hintLine("• 每成功邀请 1 位好友，双方各获得 +5 额度")
                hintLine("• 额度为全平台共享，TikTok 和 Kwai 合计计算")
                hintLine("• 超出额度的广告主账号不会自动入库")
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
    }

    private func hintLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .lineSpacing(2)
    }

    // MARK: - 通用 infoCard

    private func infoCard<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            content()
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
    }

    // MARK: - 复制按钮

    private func copyButton(label: String, value: String, toast: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            showToast(toast)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(AppTheme.Colors.primary)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.Colors.primaryBg)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toast

    private func toastView(_ text: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.Colors.success)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(duration: 0.3)) {
            copyToast = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.25)) {
                copyToast = nil
            }
        }
    }

    // MARK: - Loading / Error

    private var loadingState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView()
            Text("加载中...")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.Colors.warning)
            Text(msg)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Button("重试") { Task { await load() } }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Data

    private func load() async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            info = try await InviteService.shared.fetchInviteInfo()
        } catch {
            errorMessage = "加载失败，请重试"
        }
    }
}
