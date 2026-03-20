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

// MARK: - DashboardChartViewModel

@MainActor
final class DashboardChartViewModel: ObservableObject {
    @Published var dataByMetric: [ChartMetric: [ChartDataPoint]] = [:]
    @Published var isLoading = false
    @Published var hasError = false

    private let service = StatsService.shared

    func load(platform: String?) async {
        isLoading = true
        hasError = false
        let range = StatsService.last7DaysRange()
        do {
            let resp = try await service.trendReport(
                platform: platform,
                startDate: range.startDate,
                endDate: range.endDate
            )
            dataByMetric = buildChartData(from: resp.items)
        } catch {
            hasError = true
            dataByMetric = [:]
        }
        isLoading = false
    }

    private func buildChartData(from items: [TrendDataPoint]) -> [ChartMetric: [ChartDataPoint]] {
        var spend: [ChartDataPoint] = []
        var impressions: [ChartDataPoint] = []
        var clicks: [ChartDataPoint] = []

        for item in items {
            let date = item.parsedDate
            spend.append(ChartDataPoint(date: date, value: item.spend))
            impressions.append(ChartDataPoint(date: date, value: Double(item.impressions)))
            clicks.append(ChartDataPoint(date: date, value: Double(item.clicks)))
        }

        return [
            .spend:       spend,
            .impressions: impressions,
            .clicks:      clicks,
        ]
    }
}

// MARK: - DashboardChartView

struct DashboardChartView: View {

    let platform: String?

    @StateObject private var vm = DashboardChartViewModel()
    @State private var selectedMetric: ChartMetric = .spend

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
            chartBody
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
        .task { await vm.load(platform: platform) }
        .onChange(of: platform) { _, newPlatform in
            Task { await vm.load(platform: newPlatform) }
        }
    }

    @ViewBuilder
    private var chartBody: some View {
        if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .frame(height: 160)
        } else if let data = vm.dataByMetric[selectedMetric], !data.isEmpty {
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
}
