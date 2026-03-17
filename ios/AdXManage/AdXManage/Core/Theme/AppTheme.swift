import SwiftUI

// MARK: - AppTheme
// 全局设计 Token — 颜色、间距、圆角、阴影

enum AppTheme {

    // MARK: - Colors

    enum Colors {
        // Brand
        static let primary      = Color(red: 0.31, green: 0.27, blue: 0.90)   // #4F46E5 Indigo
        static let primaryLight = Color(red: 0.51, green: 0.55, blue: 0.97)   // #818CF8
        static let primaryBg    = Color(red: 0.93, green: 0.95, blue: 1.00)   // #EEF2FF

        // TikTok platform
        static let tiktokDark   = Color(red: 0.04, green: 0.04, blue: 0.04)   // #010101
        static let tiktokRed    = Color(red: 1.00, green: 0.17, blue: 0.33)   // #FE2C55

        // Semantic
        static let success      = Color(red: 0.06, green: 0.73, blue: 0.51)   // #10B981
        static let warning      = Color(red: 0.96, green: 0.62, blue: 0.04)   // #F59E0B
        static let danger       = Color(red: 0.94, green: 0.27, blue: 0.27)   // #EF4444

        // Text
        static let textPrimary  = Color(red: 0.12, green: 0.16, blue: 0.22)   // #1F2937
        static let textSecondary = Color(red: 0.42, green: 0.45, blue: 0.50)  // #6B7280

        // Surface
        static let surface      = Color.white
        static let background   = Color(red: 0.98, green: 0.98, blue: 0.98)   // #F9FAFB
        static let border       = Color(red: 0.90, green: 0.91, blue: 0.92)   // #E5E7EB
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    // MARK: - Radius

    enum Radius {
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 14
        static let xl:   CGFloat = 16
        static let pill: CGFloat = 20
    }
}

// MARK: - CardShadow ViewModifier

struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardShadow() -> some View {
        modifier(CardShadow())
    }
}
