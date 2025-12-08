import Foundation
import Supabase

final class SupabaseAuthRepositoryImpl: AuthRepository {
    private let client: SupabaseClient

    private(set) var currentUser: UserProfile?

    init(client: SupabaseClient) {
        self.client = client
    }

    func signInAsPassenger() async throws -> UserProfile {
        // MVP 简化：假设你已经有自己的登录流程
        // 这里只做：读 session + 读/写 profiles.role
        try await loadCurrentProfile(forceRole: "passenger")
    }

    func signInAsDriver() async throws -> UserProfile {
        try await loadCurrentProfile(forceRole: "driver")
    }

    func signOut() async {
        try? await client.auth.signOut()
        currentUser = nil
    }

    // MARK: - Helpers

    private func loadCurrentProfile(forceRole: String) async throws -> UserProfile {
        guard let uid = client.auth.currentUser?.id else {
            throw qcarError.notAuthenticated
        }

        // upsert profile role (MVP)
        _ = try await client
            .from("profiles")
            .upsert([
                "id": uid.uuidString,
                "role": forceRole
            ])
            .execute()

        let record: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .eq("id", value: uid.uuidString)
            .limit(1)
            .execute()
            .value

        guard let p = record.first else {
            throw qcarError.notFound("profile")
        }

        let profile = UserProfile(
            id: p.id,
            role: p.role == "driver" ? .driver : .passenger,
            name: p.name,
            phone: p.phone
        )
        currentUser = profile
        return profile
    }
}

private struct ProfileRow: Decodable {
    let id: UUID
    let role: String
    let name: String?
    let phone: String?
}
