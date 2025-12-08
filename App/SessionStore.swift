import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published var isAuthed: Bool = false

    func markAuthed() {
        isAuthed = true
    }

    func markSignedOut() {
        isAuthed = false
    }
}
