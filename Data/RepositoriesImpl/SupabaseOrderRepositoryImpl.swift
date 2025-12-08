import Foundation
import CoreLocation
import Supabase

final class SupabaseOrderRepositoryImpl: OrderRepository {
    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func createOrder(passengerId: UUID, pickup: CLLocationCoordinate2D, dropoff: CLLocationCoordinate2D?) async throws -> Order {
        struct CreateOrderPayload: Encodable {
            let passenger_id: String
            let pickup_lat: Double
            let pickup_lng: Double
            let dropoff_lat: Double?
            let dropoff_lng: Double?
            let status: String
        }
        
        let payload = CreateOrderPayload(
            passenger_id: passengerId.uuidString,
            pickup_lat: pickup.latitude,
            pickup_lng: pickup.longitude,
            dropoff_lat: dropoff?.latitude,
            dropoff_lng: dropoff?.longitude,
            status: "requested"
        )

        let rows: [OrderRecord] = try await client
            .from("orders")
            .insert(payload)
            .select()
            .execute()
            .value

        guard let r = rows.first else { throw qcarError.decodeFailed }
        return mapOrder(r)
    }

    func getPassengerOrders(passengerId: UUID) async throws -> [Order] {
        let rows: [OrderRecord] = try await client
            .from("orders")
            .select()
            .eq("passenger_id", value: passengerId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows.map(mapOrder)
    }

    func getNearbyOpenOrders(near coordinate: CLLocationCoordinate2D) async throws -> [Order] {
        let rows: [NearbyOrderRow] = try await client
            .rpc("list_nearby_open_orders", params: [
                "p_lat": coordinate.latitude,
                "p_lng": coordinate.longitude,
                "p_radius_km": 5,
                "p_limit": 50
            ])
            .execute()
            .value

        return rows.map { row in
            Order(
                id: row.order_id,
                passengerId: row.passenger_id,
                driverId: nil,
                pickup: .init(latitude: row.pickup_lat, longitude: row.pickup_lng),
                dropoff: {
                    guard let lat = row.dropoff_lat, let lng = row.dropoff_lng else { return nil }
                    return .init(latitude: lat, longitude: lng)
                }(),
                status: OrderStatus(rawValue: row.status) ?? .requested,
                createdAt: row.created_at
            )
        }
    }

    func acceptOrder(orderId: UUID, driverId: UUID) async throws -> Order {
        // 强制用 RPC 原子接单
        let r: OrderRecord = try await client
            .rpc("accept_order", params: ["p_order_id": orderId.uuidString])
            .execute()
            .value

        return mapOrder(r)
    }

    func updateStatus(orderId: UUID, status: OrderStatus) async throws -> Order {
        let r: OrderRecord = try await client
            .rpc("set_order_status", params: [
                "p_order_id": orderId.uuidString,
                "p_new_status": status.rawValue
            ])
            .execute()
            .value

        return mapOrder(r)
    }

    func getOrder(by id: UUID) async throws -> Order? {
        let rows: [OrderRecord] = try await client
            .from("orders")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first.map(mapOrder)
    }

    // MARK: - Mapping

    private func mapOrder(_ r: OrderRecord) -> Order {
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
