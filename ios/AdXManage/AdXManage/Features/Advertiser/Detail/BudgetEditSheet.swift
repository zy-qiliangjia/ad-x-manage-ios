import SwiftUI

// MARK: - BudgetEditSheet
// 修改预算的通用底部 Sheet，Campaign (I7) 和 AdGroup (I8) 共用。
// 4.6: 快捷金额按钮 + presentationDetents([.height(340)])

struct BudgetEditSheet: View {

    let itemName: String
    let currentBudget: Double
    let budgetMode: String
    let onSubmit: (Double) async -> Void

    @State private var inputText: String
    @State private var isSubmitting  = false
    @State private var validationErr: String? = nil
    @Environment(\.dismiss) private var dismiss

    private let quickAmounts: [Double] = [500, 1000, 2000, 5000]

    init(itemName: String,
         currentBudget: Double,
         budgetMode: String,
         onSubmit: @escaping (Double) async -> Void) {
        self.itemName      = itemName
        self.currentBudget = currentBudget
        self.budgetMode    = budgetMode
        self.onSubmit      = onSubmit
        let initial = (budgetMode == "BUDGET_MODE_INFINITE" || currentBudget <= 0)
            ? "" : String(format: "%.0f", currentBudget)
        _inputText = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("取消") { dismiss() }
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .disabled(isSubmitting)
                Spacer()
                Text("修改预算")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                if isSubmitting {
                    ProgressView().frame(width: 44)
                } else {
                    Button("确认") { Task { await submit() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(isInputValid ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                        .disabled(!isInputValid)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)

            Divider()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // 对象名称
                Text(itemName)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, AppTheme.Spacing.lg)

                // 金额输入行
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text("¥")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    TextField("输入金额", text: $inputText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .onChange(of: inputText) { _, _ in validationErr = nil }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)

                // 当前预算
                if currentBudget > 0 && budgetMode != "BUDGET_MODE_INFINITE" {
                    Text("当前预算：¥\(Int(currentBudget))")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }

                // 错误提示
                if let err = validationErr {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.danger)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }

                // 快捷金额按钮
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(quickAmounts, id: \.self) { amount in
                        Button {
                            inputText = "\(Int(amount))"
                            validationErr = nil
                        } label: {
                            Text("¥\(Int(amount))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    parsedValue == amount
                                    ? AppTheme.Colors.primary
                                    : AppTheme.Colors.textSecondary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.sm)
                                .background(
                                    parsedValue == amount
                                    ? AppTheme.Colors.primaryBg
                                    : AppTheme.Colors.background
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                                        .stroke(
                                            parsedValue == amount
                                            ? AppTheme.Colors.primary.opacity(0.4)
                                            : AppTheme.Colors.border,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
            .padding(.top, AppTheme.Spacing.md)

            Spacer()
        }
        .background(AppTheme.Colors.surface)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSubmitting)
    }

    private var parsedValue: Double? {
        Double(inputText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private var isInputValid: Bool {
        guard let v = parsedValue else { return false }
        return v > 0
    }

    private func submit() async {
        guard let value = parsedValue, value > 0 else {
            validationErr = "请输入大于 0 的金额"
            return
        }
        isSubmitting  = true
        validationErr = nil
        await onSubmit(value)
        isSubmitting  = false
        dismiss()
    }
}
