import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published var isAuthed: Bool = false
    @Published var role: UserRole = .passenger

    func markAuthed(role: UserRole) {
        self.isAuthed = true
        self.role = role
    }

    func markSignedOut() {
        self.isAuthed = false
        self.role = .passenger
    }

    func updateRole(_ role: UserRole) {
        self.role = role
    }
}
