import Foundation

protocol AuthRepository {
    var currentUser: UserProfile? { get }
    func signInAsPassenger() async throws -> UserProfile
    func signInAsDriver() async throws -> UserProfile
    func signOut() async
}
