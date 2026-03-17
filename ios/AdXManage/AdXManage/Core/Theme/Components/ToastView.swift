import SwiftUI

// MARK: - ToastManager

@MainActor
final class ToastManager: ObservableObject {
    @Published var message: String? = nil
    private var hideTask: Task<Void, Never>?

    func show(_ text: String, duration: TimeInterval = 2.0) {
        message = text
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            message = nil
        }
    }
}

// MARK: - ToastView

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(AppTheme.Colors.textPrimary)
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - ToastOverlay ViewModifier

struct ToastOverlay: ViewModifier {
    @ObservedObject var toast: ToastManager

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let msg = toast.message {
                ToastView(message: msg)
                    .padding(.top, 60)
                    .zIndex(999)
                    .animation(.spring(response: 0.35), value: toast.message)
            }
        }
        .animation(.spring(response: 0.35), value: toast.message)
    }
}

extension View {
    func toastOverlay(_ toast: ToastManager) -> some View {
        modifier(ToastOverlay(toast: toast))
    }
}
