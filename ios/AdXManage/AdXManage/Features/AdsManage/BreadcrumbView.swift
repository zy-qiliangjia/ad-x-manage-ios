import SwiftUI

// MARK: - BreadcrumbNode

struct BreadcrumbNode: Identifiable, Equatable {
    let id: Int
    let label: String
    let action: (() -> Void)?

    static func == (lhs: BreadcrumbNode, rhs: BreadcrumbNode) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - BreadcrumbView
// 显示当前层级路径。前置节点可点击返回，current 节点（最后一个）不可点击。

struct BreadcrumbView: View {
    let nodes: [BreadcrumbNode]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    let isCurrent = index == nodes.count - 1

                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
                    }

                    if isCurrent {
                        Text(node.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                    } else {
                        Button {
                            node.action?()
                        } label: {
                            Text(node.label)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.Colors.primary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.surface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

// MARK: - DimensionTab

enum AdsDimension: String, CaseIterable {
    case account  = "账号"
    case campaign = "推广系列"
    case adGroup  = "广告组"
    case ad       = "广告"
}

struct DimensionTabRow: View {
    let activeDimension: AdsDimension
    var onSelect: (AdsDimension) -> Void = { _ in }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(AdsDimension.allCases, id: \.self) { dim in
                    dimensionTab(dim)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.surface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func dimensionTab(_ dim: AdsDimension) -> some View {
        let isActive = dim == activeDimension
        return Button {
            onSelect(dim)
        } label: {
            VStack(spacing: 0) {
                Text(dim.rawValue)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)

                // 下划线指示器
                Rectangle()
                    .fill(isActive ? AppTheme.Colors.primary : Color.clear)
                    .frame(height: 2.5)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }
}
