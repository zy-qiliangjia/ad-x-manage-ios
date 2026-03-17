import SwiftUI

// MARK: - BalanceSheetView
// 以 Sheet 形式弹出，实时查询并展示广告主余额。

struct BalanceSheetView: View {

    let advertiser: AdvertiserListItem
    @Environment(\.dismiss) private var dismiss

    @State private var balance: BalanceResponse? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private let service = AdvertiserService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("正在查询余额…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let balance {
                    balanceContent(balance)
                } else if let errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("重试") { Task { await fetchBalance() } }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("账户余额")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await fetchBalance() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .task { await fetchBalance() }
    }

    // MARK: - 余额内容

    private func balanceContent(_ b: BalanceResponse) -> some View {
        VStack(spacing: 32) {
            // 广告主信息
            VStack(spacing: 4) {
                if let platform = advertiser.platformEnum {
                    PlatformBadge(platform: platform)
                }
                Text(advertiser.advertiserName)
                    .font(.headline)
                Text(advertiser.advertiserID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 余额大字
            VStack(spacing: 6) {
                Text("可用余额")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(b.currency)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(b.balance, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 网络请求

    private func fetchBalance() async {
        isLoading    = true
        errorMessage = nil
        do {
            balance = try await service.balance(id: advertiser.id)
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - PlatformBadge（跨文件复用）

struct PlatformBadge: View {
    let platform: Platform

    var body: some View {
        Text(platform.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(platform.brandColor.opacity(0.12))
            .foregroundStyle(platform.brandColor)
            .clipShape(Capsule())
    }
}
