import Foundation
import Supabase
import CoreLocation

extension SupabaseOrderRepositoryImpl {
    func getMyActiveDriverOrders(driverId: UUID) async throws -> [Order] {
        let rows: [OrderRecord] = try await client
            .from("orders")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .not("status", operator: .in, value: "(completed,cancelled)")
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows.map { r in
            Order(
                id: r.id,
                passengerId: r.passenger_id,
                driverId: r.driver_id,
                pickup: .init(latitude: r.pickup_lat, longitude: r.pickup_lng),
                dropoff: {
                    guard let lat = r.dropoff_lat, let lng = r.dropoff_lng else { return nil }
                    return .init(latitude: lat, longitude: lng)
                }(),
                status: OrderStatus(rawValue: r.status) ?? .requested,
                createdAt: r.created_at
            )
        }
    }
}
