import SwiftUI

// MARK: - AdvertiserAccountManageView

struct AdvertiserAccountManageView: View {

    @State private var quota:       UserQuota? = nil
    @State private var isLoading                = false
    @State private var errorMessage: String?    = nil
    @State private var navigateToInvite         = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                if isLoading {
                    loadingCard
                } else if let msg = errorMessage {
                    errorCard(msg)
                } else if let q = quota {
                    quotaSummaryCard(q)
                    platformBreakdownCard(q)
                    inviteCTAButton
                } else {
                    loadingCard
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.xl)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("广告账号管理")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToInvite) {
            InviteFriendsView()
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - 额度汇总卡片

    private func quotaSummaryCard(_ q: UserQuota) -> some View {
        VStack(spacing: 0) {
            // 渐变头部
            ZStack {
                LinearGradient(
                    colors: [AppTheme.Colors.primary, Color(red: 0.49, green: 0.23, blue: 0.93)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("账号额度")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(q.usedTotal)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("/ \(q.totalQuota)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text("已使用 / 总额度")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.vertical, AppTheme.Spacing.xl + AppTheme.Spacing.md)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))

            // 剩余提示条
            let remaining = q.totalQuota - q.usedTotal
            HStack {
                Image(systemName: remaining > 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(remaining > 0 ? AppTheme.Colors.success : AppTheme.Colors.warning)
                Text(remaining > 0
                     ? "还可添加 \(remaining) 个广告账号"
                     : "账号额度已用尽，邀请好友可获得更多")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
            .cardShadow()
            .padding(.top, AppTheme.Spacing.sm)
        }
    }

    // MARK: - 平台分布卡片

    private func platformBreakdownCard(_ q: UserQuota) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("各平台使用情况")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            VStack(spacing: AppTheme.Spacing.lg) {
                if q.platforms.isEmpty {
                    Text("暂无授权平台")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, AppTheme.Spacing.lg)
                } else {
                    ForEach(q.platforms) { item in
                        platformRow(item: item, total: q.totalQuota)
                    }
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
            .cardShadow()
        }
    }

    private func platformRow(item: PlatformQuotaItem, total: Int) -> some View {
        let progress = total > 0 ? Double(item.used) / Double(total) : 0.0
        let platform = Platform(rawValue: item.platform)
        let color: Color = {
            switch item.platform {
            case "tiktok": return AppTheme.Colors.tiktokRed
            case "kwai":   return Color(red: 1.00, green: 0.51, blue: 0.00)
            default:       return AppTheme.Colors.primary
            }
        }()

        return VStack(spacing: AppTheme.Spacing.sm) {
            HStack {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                            .fill(color.opacity(0.12))
                            .frame(width: 30, height: 30)
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 13))
                            .foregroundStyle(color)
                    }
                    Text(platform?.displayName ?? item.platform)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                Spacer()
                Text("\(item.used) / \(total) 个")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.Colors.border)
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * progress), height: 6)
                        .animation(.spring(duration: 0.6), value: progress)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - 邀请 CTA

    private var inviteCTAButton: some View {
        Button { navigateToInvite = true } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("邀请好友，获得更多额度")
                        .font(.system(size: 14, weight: .semibold))
                    Text("每成功邀请 1 人，双方各获得 +5 个额度")
                        .font(.system(size: 11))
                        .opacity(0.75)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(AppTheme.Colors.primary)
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.primaryBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(AppTheme.Colors.primary.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading / Error

    private var loadingCard: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView()
            Text("加载中...")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.Colors.warning)
            Text(msg)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
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
            quota = try await InviteService.shared.fetchQuota()
        } catch {
            errorMessage = "加载失败，请重试"
        }
    }
}
