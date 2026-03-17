import SwiftUI

// MARK: - AdvertiserStatusBadgeView
// 广告主账号状态 badge：活跃 / 暂停 / 异常

enum AdvertiserStatus {
    case active, paused, error

    init(isActive: Bool) {
        self = isActive ? .active : .paused
    }

    var label: String {
        switch self {
        case .active: return "活跃"
        case .paused: return "暂停"
        case .error:  return "异常"
        }
    }

    var color: Color {
        switch self {
        case .active: return AppTheme.Colors.success
        case .paused: return AppTheme.Colors.warning
        case .error:  return AppTheme.Colors.danger
        }
    }
}

struct AdvertiserStatusBadgeView: View {
    let advertiserStatus: AdvertiserStatus

    init(_ status: AdvertiserStatus) {
        self.advertiserStatus = status
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(advertiserStatus.color)
                .frame(width: 6, height: 6)
            Text(advertiserStatus.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(advertiserStatus.color.opacity(0.12))
        .foregroundStyle(advertiserStatus.color)
        .clipShape(Capsule())
    }
}
