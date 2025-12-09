import Foundation
import Supabase
import CoreLocation

extension SupabaseOrderRepositoryImpl {

    /// 司机查看自己所有订单（含历史）
    func getMyDriverOrders(
        driverId: UUID,
        limit: Int = 100
    ) async throws -> [Order] {

        let rows: [OrderRecord] = try await client
            .from("orders")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
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
