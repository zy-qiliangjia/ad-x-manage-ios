import SwiftUI
import Charts

// MARK: - 图表指标

enum ChartMetric: String, CaseIterable {
    case spend       = "消耗"
    case impressions = "展示"
    case clicks      = "点击"
}

// MARK: - 图表数据点

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - DashboardChartView

struct DashboardChartView: View {

    @State private var selectedMetric: ChartMetric = .spend

    // Mock 近 7 日数据（待接入真实时序接口）
    private let mockData: [ChartMetric: [ChartDataPoint]] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days: [Date] = (0..<7).map { offset in
            cal.date(byAdding: .day, value: offset - 6, to: today)!
        }
        return [
            .spend: zip(days, [1520.0, 1780, 1640, 1950, 2100, 1890, 1920])
                .map { ChartDataPoint(date: $0, value: $1) },
            .impressions: zip(days, [160.0, 175, 168, 190, 210, 180, 185])
                .map { ChartDataPoint(date: $0, value: $1) },
            .clicks: zip(days, [5800.0, 6200, 5900, 7100, 7500, 6400, 6300])
                .map { ChartDataPoint(date: $0, value: $1) },
        ]
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {

            // 标题
            Text("数据趋势（近7天）")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            // 指标切换 Tab
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(ChartMetric.allCases, id: \.self) { metric in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMetric = metric
                        }
                    } label: {
                        Text(metric.rawValue)
                            .font(.system(size: 12, weight: selectedMetric == metric ? .semibold : .regular))
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, 6)
                            .background(
                                selectedMetric == metric
                                ? AppTheme.Colors.primaryBg
                                : AppTheme.Colors.background
                            )
                            .foregroundStyle(
                                selectedMetric == metric
                                ? AppTheme.Colors.primary
                                : AppTheme.Colors.textSecondary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // 图表
            if let data = mockData[selectedMetric] {
                Chart(data) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value(selectedMetric.rawValue, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.primaryLight],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(6)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { value in
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppTheme.Colors.border)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: selectedMetric)
            } else {
                Text("暂无趋势数据")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 160)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
    }
}
