import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: SessionStore
    @State private var checking = true

    var body: some View {
        Group {
            if checking {
                ProgressView("检查登录状态…")
            } else if session.isAuthed {
                MainTabView(container: container)
            } else {
                AuthView(container: container) {
                    let role = container.authRepo.currentUser?.role ?? .passenger
                    session.markAuthed(role: role)
                }
            }
        }
        .task {
            checking = true
            defer { checking = false }

            if let role = container.authRepo.currentUser?.role {
                session.markAuthed(role: role)
            } else {
                session.markSignedOut()
            }
        }
    }
}
