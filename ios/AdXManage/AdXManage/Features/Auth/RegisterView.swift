import SwiftUI

// MARK: - RegisterView
// 以 Sheet 形式从 LoginView 弹出。

struct RegisterView: View {

    @EnvironmentObject private var appState: AppState
    @ObservedObject var vm: LoginViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("账号信息") {
                    TextField("昵称", text: $vm.regName)
                        .autocorrectionDisabled()

                    TextField("邮箱", text: $vm.regEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                }

                Section("密码") {
                    SecureField("密码（至少 8 位）", text: $vm.regPassword)
                        .textContentType(.oneTimeCode)

                    SecureField("确认密码", text: $vm.regPasswordConfirm)
                        .textContentType(.oneTimeCode)

                    if vm.registerPasswordMismatch {
                        Label("两次密码不一致", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                if let msg = vm.errorMessage {
                    Section {
                        Label(msg, systemImage: "xmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await vm.register(appState: appState) }
                    } label: {
                        Group {
                            if vm.isLoading {
                                ProgressView()
                            } else {
                                Text("注册并登录")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .disabled(!vm.canRegister)
                }
            }
            .navigationTitle("创建账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        vm.errorMessage = nil
                        dismiss()
                    }
                }
            }
        }
    }
}
