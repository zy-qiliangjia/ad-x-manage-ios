import SwiftUI

// MARK: - DateRangePickerView

/// 嵌入账号列表顶部的日期区间选择器，最大跨度30天。
struct DateRangePickerView: View {

    @Binding var startDate: Date
    @Binding var endDate: Date
    var onChanged: () -> Void

    @State private var showToast = false

    private static let maxSpan: TimeInterval = 30 * 24 * 3600

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "calendar")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            DatePicker(
                "",
                selection: $startDate,
                in: ...endDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .font(.system(size: 13))
            .onChange(of: startDate) { _, newStart in
                clampEndDate(from: newStart)
            }

            Text("–")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            DatePicker(
                "",
                selection: $endDate,
                in: startDate...,
                displayedComponents: .date
            )
            .labelsHidden()
            .font(.system(size: 13))
            .onChange(of: endDate) { _, newEnd in
                clampEndDate(from: startDate, proposedEnd: newEnd)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(.bar)
        .overlay(alignment: .top) {
            if showToast {
                Text("日期跨度最多30天")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showToast)
    }

    // MARK: - 日期截断逻辑

    private func clampEndDate(from start: Date, proposedEnd: Date? = nil) {
        let candidate = proposedEnd ?? endDate
        let maxEnd = start.addingTimeInterval(Self.maxSpan)
        if candidate > maxEnd {
            endDate = maxEnd
            flashToast()
        }
        onChanged()
    }

    private func flashToast() {
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
}
