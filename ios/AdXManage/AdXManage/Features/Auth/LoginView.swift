import SwiftUI

// MARK: - LoginView

struct LoginView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = LoginViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // ── Logo 区域 ──────────────────────────
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 56))
                            .foregroundStyle(.blue)
                        Text("AdX Manage")
                            .font(.title.bold())
                        Text("广告聚合管理平台")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 48)

                    // ── 表单 ───────────────────────────────
                    VStack(spacing: 16) {
                        TextField("邮箱", text: $vm.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField("密码（至少 8 位）", text: $vm.password)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                Task { await vm.login(appState: appState) }
                            }

                        // ── 错误提示 ──────────────────────
                        if let msg = vm.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(msg)
                                    .font(.footnote)
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // ── 登录按钮 ──────────────────────
                        Button {
                            Task { await vm.login(appState: appState) }
                        } label: {
                            Group {
                                if vm.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("登录")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!vm.canLogin)
                    }
                    .padding(.horizontal, 24)

                    // ── 注册入口 ───────────────────────────
                    Button("没有账号？立即注册") {
                        vm.errorMessage = nil
                        vm.showRegister = true
                    }
                    .font(.footnote)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $vm.showRegister) {
                RegisterView(vm: vm)
                    .environmentObject(appState)
            }
        }
    }
}
