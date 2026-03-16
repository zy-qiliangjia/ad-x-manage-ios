import SwiftUI

// MARK: - PlatformSelectionView
// 以 Sheet 形式弹出，列出可授权的广告平台。
// 确认选择后由父视图发起 OAuth 流程（I4）。

struct PlatformSelectionView: View {

    /// 用户选中某个平台后的回调
    let onSelect: (Platform) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ── 说明文字 ───────────────────────────
                    VStack(spacing: 6) {
                        Text("选择广告平台")
                            .font(.title2.bold())
                        Text("选择后将跳转至平台官网完成授权")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // ── 平台卡片列表 ────────────────────────
                    VStack(spacing: 14) {
                        ForEach(Platform.allCases) { platform in
                            PlatformCard(platform: platform) {
                                dismiss()
                                onSelect(platform)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - PlatformCard

private struct PlatformCard: View {

    let platform: Platform
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标区域
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(platform.brandColor)
                        .frame(width: 56, height: 56)

                    // 优先使用 Assets 中的自定义图标，回退到 SF Symbol
                    Group {
                        if UIImage(named: platform.assetName) != nil {
                            Image(platform.assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 34, height: 34)
                        } else {
                            Image(systemName: platform.symbolName)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                }

                // 文字区域
                VStack(alignment: .leading, spacing: 3) {
                    Text(platform.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(platform.subTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(platform.description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true  } }
                .onEnded   { _ in withAnimation(.easeInOut(duration: 0.15)) { isPressed = false } }
        )
    }
}
