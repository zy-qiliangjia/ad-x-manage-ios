import SwiftUI

// MARK: - ContactGuideSheet
// 体验模式下点击任意位置弹出的底部引导弹窗
// 展示客服联系方式（地址由服务端下发），底部提供登录入口

struct ContactGuideSheet: View {

    @Binding var isPresented: Bool
    let config: AppConfig?
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // ── 拖拽指示条 ──────────────────────────────────
            Capsule()
                .fill(Color(UIColor.systemGray4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)

            // ── 图标 + 标题 ──────────────────────────────────
            VStack(spacing: 6) {
                Text("📊")
                    .font(.system(size: 36))
                Text("开通 AdX Manage 账号")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("添加客服，告知您的需求，即可开通")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // ── 联系方式卡片 ────────────────────────────────
            HStack(spacing: 12) {
                ContactOptionCard(
                    emoji: "💬",
                    iconBg: Color(red: 0.027, green: 0.757, blue: 0.376),
                    title: "企业微信客服",
                    subtitle: "点击跳转添加",
                    urlString: config?.wechatURL
                )
                ContactOptionCard(
                    emoji: "✈️",
                    iconBg: Color(red: 0, green: 0.533, blue: 0.8),
                    title: "Telegram 客服",
                    subtitle: "点击跳转添加",
                    urlString: config?.telegramURL
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            // ── 登录入口 ─────────────────────────────────────
            HStack(spacing: 4) {
                Text("已有账号？")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Button("点此登录") {
                    isPresented = false
                    onLogin()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primary)
            }
            .padding(.bottom, 28)
        }
        .background(AppTheme.Colors.surface)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }
}

// MARK: - ContactOptionCard

private struct ContactOptionCard: View {

    let emoji: String
    let iconBg: Color
    let title: String
    let subtitle: String
    let urlString: String?

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            guard let str = urlString, !str.isEmpty,
                  let url = URL(string: str) else { return }
            openURL(url)
        } label: {
            VStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 28))
                    .frame(width: 56, height: 56)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(AppTheme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
