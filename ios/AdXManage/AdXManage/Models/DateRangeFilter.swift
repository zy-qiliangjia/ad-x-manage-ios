import SwiftUI

// MARK: - DateRangeFilter
// 日期范围筛选，供 Dashboard 和广告汇总卡片共用。

enum DateRangeFilter: Hashable, Identifiable {
    case today
    case yesterday
    case last7Days
    case last14Days
    case last30Days
    case thisMonth
    case lastMonth
    case custom(from: Date, to: Date)

    var id: String {
        switch self {
        case .today:                        return "today"
        case .yesterday:                    return "yesterday"
        case .last7Days:                    return "last7days"
        case .last14Days:                   return "last14days"
        case .last30Days:                   return "last30days"
        case .thisMonth:                    return "thismonth"
        case .lastMonth:                    return "lastmonth"
        case .custom(let f, let t):
            return "custom-\(f.timeIntervalSince1970)-\(t.timeIntervalSince1970)"
        }
    }

    var label: String {
        switch self {
        case .today:      return "今天"
        case .yesterday:  return "昨天"
        case .last7Days:  return "近7天"
        case .last14Days: return "近14天"
        case .last30Days: return "近30天"
        case .thisMonth:  return "本月"
        case .lastMonth:  return "上月"
        case .custom:     return "自定义"
        }
    }

    /// 所有预设排列顺序，用于选择器列表。
    static let presets: [DateRangeFilter] = [
        .today, .yesterday, .last7Days, .last14Days, .last30Days, .thisMonth, .lastMonth, .custom(from: Date(), to: Date())
    ]

    /// 供 AdsSummaryCardView 的横向 tab 条使用的 4 个快捷选项。
    static let tabPresets: [DateRangeFilter] = [.today, .yesterday, .last7Days, .last30Days]

    // MARK: - Date computation

    private static let apiFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let subtitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM.dd"
        return f
    }()

    /// 返回 API 使用的 "yyyy-MM-dd" 字符串范围。
    var dateRange: (from: String, to: String) {
        let cal  = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch self {
        case .today:
            let s = Self.apiFormatter.string(from: today)
            return (s, s)
        case .yesterday:
            let y = cal.date(byAdding: .day, value: -1, to: today)!
            let s = Self.apiFormatter.string(from: y)
            return (s, s)
        case .last7Days:
            let start = cal.date(byAdding: .day, value: -6, to: today)!
            return (Self.apiFormatter.string(from: start), Self.apiFormatter.string(from: today))
        case .last14Days:
            let start = cal.date(byAdding: .day, value: -13, to: today)!
            return (Self.apiFormatter.string(from: start), Self.apiFormatter.string(from: today))
        case .last30Days:
            let start = cal.date(byAdding: .day, value: -29, to: today)!
            return (Self.apiFormatter.string(from: start), Self.apiFormatter.string(from: today))
        case .thisMonth:
            let comps     = cal.dateComponents([.year, .month], from: today)
            let firstDay  = cal.date(from: comps)!
            return (Self.apiFormatter.string(from: firstDay), Self.apiFormatter.string(from: today))
        case .lastMonth:
            let firstOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: today))!
            let lastOfPrev       = cal.date(byAdding: .day, value: -1, to: firstOfThisMonth)!
            let firstOfPrev      = cal.date(from: cal.dateComponents([.year, .month], from: lastOfPrev))!
            return (Self.apiFormatter.string(from: firstOfPrev), Self.apiFormatter.string(from: lastOfPrev))
        case .custom(let from, let to):
            return (Self.apiFormatter.string(from: from), Self.apiFormatter.string(from: to))
        }
    }

    /// 副标题：显示具体日期跨度，如 "03.11 – 03.17"。
    var subtitle: String {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sub   = Self.subtitleFormatter

        switch self {
        case .today:
            return sub.string(from: today)
        case .yesterday:
            let y = cal.date(byAdding: .day, value: -1, to: today)!
            return sub.string(from: y)
        case .last7Days:
            let start = cal.date(byAdding: .day, value: -6, to: today)!
            return "\(sub.string(from: start)) – \(sub.string(from: today))"
        case .last14Days:
            let start = cal.date(byAdding: .day, value: -13, to: today)!
            return "\(sub.string(from: start)) – \(sub.string(from: today))"
        case .last30Days:
            let start = cal.date(byAdding: .day, value: -29, to: today)!
            return "\(sub.string(from: start)) – \(sub.string(from: today))"
        case .thisMonth:
            let first = cal.date(from: cal.dateComponents([.year, .month], from: today))!
            return "\(sub.string(from: first)) – \(sub.string(from: today))"
        case .lastMonth:
            let firstOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: today))!
            let lastOfPrev       = cal.date(byAdding: .day, value: -1, to: firstOfThisMonth)!
            let firstOfPrev      = cal.date(from: cal.dateComponents([.year, .month], from: lastOfPrev))!
            return "\(sub.string(from: firstOfPrev)) – \(sub.string(from: lastOfPrev))"
        case .custom(let from, let to):
            return "\(sub.string(from: from)) – \(sub.string(from: to))"
        }
    }
}

// MARK: - DateRangeTabView
// 横向 4 格快捷选项条，供广告汇总卡片使用。

struct DateRangeTabView: View {
    @Binding var selected: DateRangeFilter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DateRangeFilter.tabPresets) { filter in
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
