import SwiftUI

// MARK: - DashboardDatePickerSheet
// 日期范围选择底部 Sheet，供 DashboardView 使用。

struct DashboardDatePickerSheet: View {

    @Binding var dateFilter: DateRangeFilter
    @Environment(\.dismiss) private var dismiss

    @State private var pendingPreset: DateRangeFilter = .last7Days
    @State private var customFrom: Date = Date()
    @State private var customTo: Date = Date()
    @State private var showCustomPickers = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(DateRangeFilter.presets) { filter in
                    if case .custom = filter {
                        customRow
                    } else {
                        presetRow(filter)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("选择时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            pendingPreset = dateFilter
            if case .custom(let f, let t) = dateFilter {
                customFrom = f
                customTo   = t
                showCustomPickers = true
            }
        }
    }

    // MARK: - Preset Row

    private func presetRow(_ filter: DateRangeFilter) -> some View {
        Button {
            pendingPreset = filter
            dateFilter    = filter
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(filter.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text(filter.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
                if pendingPreset == filter {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Row

    private var customRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行 — tap toggles pickers
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    pendingPreset = .custom(from: customFrom, to: customTo)
                    showCustomPickers = true
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("自定义")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                        if case .custom(let f, let t) = pendingPreset {
                            let sub = "\(subtitleFmt(f)) – \(subtitleFmt(t))"
                            Text(sub)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        } else {
                            Text("选择起止日期")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                    Spacer()
                    if case .custom = pendingPreset {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 内联日期选择器
            if showCustomPickers {
                VStack(spacing: 0) {
                    Divider().padding(.top, 10)

                    DatePicker("开始日期", selection: $customFrom, displayedComponents: .date)
                        .onChange(of: customFrom) { _ in
                            pendingPreset = .custom(from: customFrom, to: customTo)
                        }
                        .padding(.vertical, 6)

                    DatePicker("结束日期", selection: $customTo, displayedComponents: .date)
                        .onChange(of: customTo) { _ in
                            pendingPreset = .custom(from: customFrom, to: customTo)
                        }
                        .padding(.vertical, 6)

                    Divider().padding(.bottom, 6)

                    // 确认 / 取消
                    HStack(spacing: AppTheme.Spacing.md) {
                        Button("取消") { dismiss() }
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))

                        Button("确认") {
                            dateFilter = .custom(from: customFrom, to: customTo)
                            dismiss()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(customTo >= customFrom ? AppTheme.Colors.primary : Color.gray.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                        .disabled(customTo < customFrom)
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    // MARK: - Helpers

    private func subtitleFmt(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM.dd"
        return f.string(from: date)
    }
}
