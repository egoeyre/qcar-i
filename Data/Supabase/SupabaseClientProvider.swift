import Foundation
import Supabase

protocol SupabaseClientProvider {
    var client: SupabaseClient { get }
}

final class DefaultSupabaseClientProvider: SupabaseClientProvider {
    let client: SupabaseClient

    init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
}
