import SwiftUI

// MARK: - PlatformBadgeView
// 平台标签 badge（TikTok / 快手）
// 替换原 BalanceSheetView 中的 PlatformBadge，保持 API 兼容

struct PlatformBadgeView: View {
    let platform: Platform

    var body: some View {
        Text(platform.displayName)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeBg)
            .foregroundStyle(badgeFg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm / 2))
    }

    private var badgeBg: Color {
        switch platform {
        case .tiktok: return AppTheme.Colors.tiktokRed.opacity(0.10)
        case .kwai:   return Color.orange.opacity(0.10)
        }
    }

    private var badgeFg: Color {
        switch platform {
        case .tiktok: return AppTheme.Colors.tiktokRed
        case .kwai:   return .orange
        }
    }
}
