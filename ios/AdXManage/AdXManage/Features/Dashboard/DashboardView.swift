import SwiftUI

// MARK: - DashboardViewModel

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var overview: StatsOverview? = nil
    @Published var isLoading  = false
    @Published var error: String? = nil
    @Published var platformFilter: Platform? = nil {
        didSet { Task { await load() } }
    }
    @Published var dateFilter: DateRangeFilter = .last30Days {
        didSet { Task { await load() } }
    }
    @Published var lastFetchedAt: Date? = nil

    private let service = StatsService.shared

    var lastFetchedLabel: String? {
        guard let d = lastFetchedAt else { return nil }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            let range = dateFilter.dateRange
            overview = try await service.overview(
                platform: platformFilter?.rawValue,
                startDate: range.from,
                endDate: range.to
            )
            lastFetchedAt = Date()
        } catch is CancellationError {
            // view teardown — suppress
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - DashboardView

struct DashboardView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = DashboardViewModel()
    @State private var showDatePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 渐变 Header（固定在 ScrollView 外，避免被 ScrollView 裁切背景）
            headerSection

            // 内容区
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // 统计卡片
                    if vm.isLoading && vm.overview == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let ov = vm.overview {
                        statsGrid(ov)
                    }

                    // 趋势图
                    DashboardChartView()
                        .padding(.horizontal, AppTheme.Spacing.xl)

                    Spacer(minLength: AppTheme.Spacing.xl)
                }
                .padding(.top, AppTheme.Spacing.lg)
            }
            .background(AppTheme.Colors.background)
            .refreshable { if appState.isLoggedIn { await vm.load() } }
        }
        .background(AppTheme.Colors.background)
        .alert("加载失败", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("确定", role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
        .task {
            if appState.isLoggedIn {
                await vm.load()
            } else {
                vm.overview      = DemoData.overview
                vm.lastFetchedAt = Date()
            }
        }
        // 登录后切换为真实数据
        .onChange(of: appState.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn { Task { await vm.load() } }
        }
        .sheet(isPresented: $showDatePicker) {
            DashboardDatePickerSheet(dateFilter: $vm.dateFilter)
        }
    }

    // MARK: - 渐变 Header

    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // 标题行
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("掌上AD")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text("广告账户管理工具")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                // 更新时间
                HStack(spacing: 6) {
                    if vm.isLoading {
                        ProgressView().scaleEffect(0.6).tint(.white)
                    } else {
                        Circle()
                            .fill(AppTheme.Colors.success)
                            .frame(width: 7, height: 7)
                    }
                    Text(vm.lastFetchedLabel.map { "更新于 \($0)" } ?? "数据已更新")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.15))
                .clipShape(Capsule())
            }

            // 平台筛选 Tab（全部 / TikTok）
            HStack(spacing: AppTheme.Spacing.sm) {
                platformTab(title: "全部平台", platform: nil)
                platformTab(title: "TikTok", platform: .tiktok, dot: AppTheme.Colors.tiktokRed)
            }

            // 日期范围筛选 Chip
            HStack {
                Button { showDatePicker = true } label: {
                    HStack(spacing: 6) {
                        Text("\(vm.dateFilter.label)  \(vm.dateFilter.subtitle)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.surface)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.xl)
        .padding(.bottom, AppTheme.Spacing.xl)
        .background {
            LinearGradient(
                colors: [AppTheme.Colors.primary, Color(red: 0.49, green: 0.23, blue: 0.93)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: appState.isLoggedIn ? .top : [])
        }
    }

    @ViewBuilder
    private func platformTab(title: String, platform: Platform?, dot: Color? = nil) -> some View {
        let isSelected = vm.platformFilter == platform
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.platformFilter = platform
            }
        } label: {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 7, height: 7)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(isSelected ? .white : .white.opacity(0.18))
            .foregroundStyle(isSelected ? AppTheme.Colors.primary : .white.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 统计卡片网格

    private func statsGrid(_ ov: StatsOverview) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppTheme.Spacing.md
        ) {
            DashStatCard(
                icon: "dollarsign.circle.fill",
                color: AppTheme.Colors.warning,
                value: ov.totalSpend.statFormatted,
                label: "总消耗"
            )
            DashStatCard(
                icon: "cursorarrow.click.2",
                color: .blue,
                value: ov.totalClicks.statFormatted,
                label: "总点击"
            )
            DashStatCard(
                icon: "eye.fill",
                color: .indigo,
                value: ov.totalImpressions.statFormatted,
                label: "总展示"
            )
            DashStatCard(
                icon: "star.fill",
                color: .orange,
                value: ov.totalConversions.statFormatted,
                label: "总转化"
            )
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
    }
}

// MARK: - DashStatCard

private struct DashStatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(color)

            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .padding(.horizontal, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .cardShadow()
    }
}

