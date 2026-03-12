import SwiftUI

// MARK: - BudgetEditSheet
// 修改预算的通用底部 Sheet，Campaign (I7) 和 AdGroup (I8) 共用。

struct BudgetEditSheet: View {

    /// 显示在表单 header 的名称（推广系列名 / 广告组名）
    let itemName: String
    let currentBudget: Double
    let budgetMode: String
    /// 确认后调用，外部负责 API 请求；成功后 dismiss 由此闭包完成
    let onSubmit: (Double) async -> Void

    @State private var inputText: String
    @State private var isSubmitting  = false
    @State private var validationErr: String? = nil
    @Environment(\.dismiss) private var dismiss

    init(itemName: String,
         currentBudget: Double,
         budgetMode: String,
         onSubmit: @escaping (Double) async -> Void) {
        self.itemName      = itemName
        self.currentBudget = currentBudget
        self.budgetMode    = budgetMode
        self.onSubmit      = onSubmit
        // 不限预算 or 0 → 输入框为空，让用户填新值
        let initial = (budgetMode == "BUDGET_MODE_INFINITE" || currentBudget <= 0)
            ? "" : String(format: "%.2f", currentBudget)
        _inputText = State(initialValue: initial)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("新预算")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("输入金额", text: $inputText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: inputText) { _, _ in validationErr = nil }
                    }
                } header: {
                    Text(itemName).lineLimit(1)
                } footer: {
                    if let err = validationErr {
                        Text(err).foregroundStyle(.red)
                    } else if currentBudget > 0 && budgetMode != "BUDGET_MODE_INFINITE" {
                        Text("当前预算：\(currentBudget.formatted(.number.precision(.fractionLength(2))))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("修改预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("确认") { Task { await submit() } }
                            .disabled(!isInputValid)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSubmitting)
    }

    // MARK: - 验证 & 提交

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
