import SwiftUI

// MARK: - OAuthProgressView
// 以 Sheet 形式展示 OAuth 授权的进行状态、广告主选择、成功结果和失败信息。

struct OAuthProgressView: View {

    @ObservedObject var vm: OAuthViewModel
    /// 授权成功后的回调，外部用于触发页面跳转
    let onSuccess: (OAuthConfirmResponse) -> Void

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
                        message: "授权成功，正在拉取广告账号列表…",
                        showSpinner: true
                    )

                case .selecting(let resp):
                    selectingView(resp)

                case .confirming:
                    statusView(
                        icon: "square.and.arrow.down",
                        iconColor: .blue,
                        title: "正在保存",
                        message: "正在保存所选广告账号，请稍候…",
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
                        .disabled(isProcessing)
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

    // MARK: - 选择广告主

    private func selectingView(_ resp: OAuthCallbackResponse) -> some View {
        let platform = Platform(rawValue: resp.platform)
        let newCount = resp.advertisers.filter { !$0.isExisting }.count
        return VStack(spacing: 0) {
            // 额度说明栏
            quotaBar(resp, newCount: newCount)

            if newCount == 0 && !resp.advertisers.isEmpty {
                // 所有广告主均已添加，显示只读列表 + 提示
                allExistingBanner()
            }

            // 广告主列表
            List(resp.advertisers) { adv in
                advertiserRow(adv, resp: resp)
                    .listRowBackground(adv.isExisting ? Color(.systemGroupedBackground) : Color(.systemBackground))
            }
            .listStyle(.insetGrouped)

            // 底部按钮
            Button {
                guard let p = platform else { return }
                vm.confirm(platform: p, resp: resp)
            } label: {
                Group {
                    if vm.selectedIDs.count > 0 {
                        Text("确认添加 \(vm.selectedIDs.count) 个账号")
                    } else if newCount == 0 {
                        Text("完成")
                    } else {
                        Text("跳过，暂不添加")
                    }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("选择广告账号")
    }

    // 当前平台所有广告主均已添加时的提示横幅
    private func allExistingBanner() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.blue)
                .font(.system(size: 14))
            Text("该平台所有广告账号均已添加")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.06))
    }

    // 额度进度栏
    private func quotaBar(_ resp: OAuthCallbackResponse, newCount: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.badge.plus")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
            Text("已用 \(resp.usedQuota) / 总额度 \(resp.quota)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            let selected = vm.selectedIDs.count
            if selected > 0 {
                Text("本次新增 \(selected)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
            } else if resp.remaining == 0 {
                Text("额度已满")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
            } else if newCount > 0 {
                Text("可再选 \(resp.remaining - selected)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            // newCount == 0 时不显示任何右侧文字，避免"可再选 20"的误导
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }

    // 单条广告主行
    @ViewBuilder
    private func advertiserRow(_ adv: OAuthAdvertiserItem, resp: OAuthCallbackResponse) -> some View {
        let isSelected = vm.selectedIDs.contains(adv.advertiserID)
        let quotaFull  = vm.selectedIDs.count >= resp.remaining && !isSelected

        Button {
            guard !adv.isExisting else { return }
            vm.toggleSelection(adv.advertiserID, resp: resp)
        } label: {
            HStack(spacing: 12) {
                // 勾选图标
                if adv.isExisting {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 22))
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(quotaFull ? Color(.systemGray4) : .secondary)
                        .font(.system(size: 22))
                }

                // 广告主信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(adv.advertiserName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(adv.isExisting || (!quotaFull || isSelected) ? .primary : .secondary)
                    Text(adv.advertiserID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 标签
                if adv.isExisting {
                    Text("已添加")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                } else {
                    Text(adv.currency)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .opacity(adv.isExisting ? 0.6 : (quotaFull && !isSelected ? 0.4 : 1.0))
        }
        .buttonStyle(.plain)
        .disabled(adv.isExisting)
    }

    // MARK: - 成功

    private func successView(_ resp: OAuthConfirmResponse) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                Text("添加成功")
                    .font(.title3.bold())
                Text(resp.advertisers.isEmpty
                     ? "广告账号已更新"
                     : "已添加 \(resp.advertisers.count) 个广告账号")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 28)

            if !resp.advertisers.isEmpty {
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
            }

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
                Text("操作失败")
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
        case .authorizing, .processing, .confirming: return true
        default: return false
        }
    }
}
