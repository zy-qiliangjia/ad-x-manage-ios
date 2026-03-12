import SwiftUI

// MARK: - Platform 枚举

enum Platform: String, CaseIterable, Identifiable {
    case tiktok = "tiktok"
    case kwai   = "kwai"

    var id: String { rawValue }

    // ── 显示信息 ───────────────────────────────────────────

    var displayName: String {
        switch self {
        case .tiktok: return "TikTok"
        case .kwai:   return "快手"
        }
    }

    var subTitle: String {
        switch self {
        case .tiktok: return "TikTok for Business"
        case .kwai:   return "快手商业化"
        }
    }

    var description: String {
        switch self {
        case .tiktok: return "管理 TikTok 广告账号的推广系列、广告组和广告"
        case .kwai:   return "管理快手商业化账号的推广系列、广告组和广告"
        }
    }

    // ── 视觉资源 ───────────────────────────────────────────

    /// SF Symbol 名称，作为自定义图标未导入前的占位
    var symbolName: String {
        switch self {
        case .tiktok: return "music.note"
        case .kwai:   return "video.fill"
        }
    }

    /// Assets.xcassets 中的图片名（添加真实品牌图标后替换 symbol）
    var assetName: String {
        switch self {
        case .tiktok: return "logo_tiktok"
        case .kwai:   return "logo_kwai"
        }
    }

    var brandColor: Color {
        switch self {
        case .tiktok: return Color(red: 0.04, green: 0.04, blue: 0.04)  // 接近纯黑
        case .kwai:   return Color(red: 1.00, green: 0.51, blue: 0.00)  // 快手橙
        }
    }

    var brandColorLight: Color {
        switch self {
        case .tiktok: return Color(red: 0.15, green: 0.15, blue: 0.15)
        case .kwai:   return Color(red: 1.00, green: 0.68, blue: 0.40)
        }
    }
}
