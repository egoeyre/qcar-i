import SwiftUI

@main
struct qcarApp: App {
    @StateObject private var container = AppDI.makeContainer()
    @StateObject private var session = SessionStore()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(session)
        }
    }
}
