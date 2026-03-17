import SwiftUI

// MARK: - DateRangeFilter

enum DateRangeFilter: String, CaseIterable, Identifiable {
    case today      = "today"
    case yesterday  = "yesterday"
    case last7Days  = "last7days"
    case last30Days = "last30days"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:      return "今天"
        case .yesterday:  return "昨天"
        case .last7Days:  return "近7天"
        case .last30Days: return "近30天"
        }
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var dateRange: (from: String, to: String) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch self {
        case .today:
            let s = Self.df.string(from: today)
            return (s, s)
        case .yesterday:
            let y = cal.date(byAdding: .day, value: -1, to: today)!
            let s = Self.df.string(from: y)
            return (s, s)
        case .last7Days:
            let start = cal.date(byAdding: .day, value: -6, to: today)!
            return (Self.df.string(from: start), Self.df.string(from: today))
        case .last30Days:
            let start = cal.date(byAdding: .day, value: -29, to: today)!
            return (Self.df.string(from: start), Self.df.string(from: today))
        }
    }
}

// MARK: - DateRangeTabView

struct DateRangeTabView: View {
    @Binding var selected: DateRangeFilter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DateRangeFilter.allCases) { filter in
                Button { selected = filter } label: {
                    Text(filter.label)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selected == filter ? Color.white : Color.white.opacity(0.2))
                        .foregroundStyle(selected == filter ? AppTheme.Colors.primary : Color.white.opacity(0.85))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

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

    var cpa: String {
        guard conversions > 0 else { return "--" }
        return String(format: "%.2f", spend / Double(conversions))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // 日期筛选 tabs
            DateRangeTabView(selected: $dateFilter)

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
