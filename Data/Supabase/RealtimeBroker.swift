import Foundation
import Supabase

protocol RealtimeBroker {
    func ordersChangeStream() async -> AsyncStream<Void>
    func driversChangeStream() async -> AsyncStream<Void>
    func orderLocationsChangeStream() async -> AsyncStream<Void>
}

final class SupabaseRealtimeBroker: RealtimeBroker {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func ordersChangeStream() async -> AsyncStream<Void> {
        await tableChangeStream(channelName: "public:orders:watch", table: "orders")
    }

    func driversChangeStream() async -> AsyncStream<Void> {
        await tableChangeStream(channelName: "public:drivers:watch", table: "drivers")
    }

    func orderLocationsChangeStream() async -> AsyncStream<Void> {
        await tableChangeStream(channelName: "public:order_locations:watch", table: "order_locations")
    }

    private func tableChangeStream(channelName: String, table: String) async -> AsyncStream<Void> {
        let channel = client.channel(channelName)
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: table)

        await channel.subscribe()

        return AsyncStream { continuation in
            let task = Task {
                for await _ in changes {
                    continuation.yield(())
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
                Task { await channel.unsubscribe() }
            }
        }
    }
}
