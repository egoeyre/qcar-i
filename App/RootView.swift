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
                    session.markAuthed()
                }
            }
        }
        .task {
            checking = true
            defer { checking = false }

            // 最轻量判断：以 repo 缓存的 currentUser 为准
            // 你也可以在 SupabaseAuthRepositoryImpl 里补一个 loadSession() 更严谨
            session.isAuthed = (container.authRepo.currentUser != nil)
        }
    }
}
