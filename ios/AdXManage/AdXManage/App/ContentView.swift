import SwiftUI

// MARK: - ContentView
// 根视图：登录前 → LoginView；登录后 → MainTabView。

struct ContentView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isLoggedIn)
    }
}
