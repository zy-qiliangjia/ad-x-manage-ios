import SwiftUI

// MARK: - AdsSummaryCardView
// 紫色渐变汇总卡片，展示当前层级的统计数据。

struct AdsSummaryCardView: View {

    let scopeLabel: String
    let spend: Double
    let clicks: Int
    let impressions: Int
    let conversions: Int
    @Binding var dateFilter: DateRangeFilter
    var isLoadingSummary: Bool = false
    var showDateTabs: Bool = true

    var cpa: String {
        guard conversions > 0 else { return "--" }
        return String(format: "%.2f", spend / Double(conversions))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // 日期筛选 tabs（由外部控制时隐藏）
            if showDateTabs {
                DateRangeTabView(selected: $dateFilter)
            }

            // 范围标签
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                Text(scopeLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }

            // 消耗大字
            Text(spend.statFormatted)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("总消耗（元）")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))

            // 分隔线
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(height: 1)

            // 四列指标
            HStack(spacing: 0) {
                summaryMetric(label: "点击", value: clicks.compactFormatted)
                Divider().frame(height: 24).overlay(Color.white.opacity(0.2))
                summaryMetric(label: "展示", value: impressions.compactFormatted)
                Divider().frame(height: 24).overlay(Color.white.opacity(0.2))
                summaryMetric(label: "转化", value: conversions.compactFormatted)
                Divider().frame(height: 24).overlay(Color.white.opacity(0.2))
                summaryMetric(label: "CPA", value: cpa)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.49, green: 0.23, blue: 0.93),
                    AppTheme.Colors.primary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
        .opacity(isLoadingSummary ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoadingSummary)
    }

    private func summaryMetric(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Formatting helpers

extension Double {
    var statFormatted: String {
        if self >= 1_000_000 { return String(format: "%.1fM", self / 1_000_000) }
        if self >= 1_000     { return String(format: "%.1fK", self / 1_000) }
        return String(format: "%.2f", self)
    }
}

extension Int {
    var compactFormatted: String {
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000) }
        if self >= 1_000     { return String(format: "%.1fK", Double(self) / 1_000) }
        return "\(self)"
    }
}
