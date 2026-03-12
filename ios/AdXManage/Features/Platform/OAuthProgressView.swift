import SwiftUI

// MARK: - OAuthProgressView
// 以 Sheet 形式展示 OAuth 授权的进行状态、成功结果和失败信息。

struct OAuthProgressView: View {

    @ObservedObject var vm: OAuthViewModel
    /// 授权成功后的回调，外部用于触发页面跳转
    let onSuccess: (OAuthCallbackResponse) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                switch vm.phase {
                case .idle:
                    EmptyView()

                case .authorizing(let platform):
                    statusView(
                        icon: platform.symbolName,
                        iconColor: platform.brandColor,
                        title: "等待授权",
                        message: "正在 \(platform.displayName) 完成授权，请在浏览器中操作…",
                        showSpinner: true
                    )

                case .processing:
                    statusView(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .blue,
                        title: "正在处理",
                        message: "授权成功，后台正在同步广告数据，请稍候…",
                        showSpinner: true
                    )

                case .success(let resp):
                    successView(resp)

                case .failure(let message, let platform):
                    failureView(message: message, platform: platform)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { vm.dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(isProcessing)
    }

    // MARK: - 状态中（loading）

    private func statusView(
        icon: String,
        iconColor: Color,
        title: String,
        message: String,
        showSpinner: Bool
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(iconColor)
                if showSpinner {
                    Circle()
                        .stroke(iconColor.opacity(0.2), lineWidth: 3)
                        .frame(width: 88, height: 88)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(iconColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: showSpinner)
                }
            }
            VStack(spacing: 8) {
                Text(title).font(.title3.bold())
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    // MARK: - 成功

    private func successView(_ resp: OAuthCallbackResponse) -> some View {
        VStack(spacing: 0) {
            // 顶部成功标识
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                Text("授权成功")
                    .font(.title3.bold())
                Text("已同步 \(resp.advertisers.count) 个广告账号")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 28)

            // 账号列表
            List(resp.advertisers) { adv in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(adv.advertiserName)
                            .font(.subheadline.weight(.medium))
                        Text(adv.advertiserID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(adv.currency)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)

            // 完成按钮
            Button {
                onSuccess(resp)
                vm.dismiss()
            } label: {
                Text("完成")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 失败

    private func failureView(message: String, platform: Platform?) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.red)
            VStack(spacing: 8) {
                Text("授权失败")
                    .font(.title3.bold())
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            HStack(spacing: 12) {
                if let platform {
                    Button("重试") {
                        vm.retry(platform: platform)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("取消", role: .cancel) {
                    vm.dismiss()
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
    }

    // MARK: -

    private var isProcessing: Bool {
        switch vm.phase {
        case .authorizing, .processing: return true
        default: return false
        }
    }
}
