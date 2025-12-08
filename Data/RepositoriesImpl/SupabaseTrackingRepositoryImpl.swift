import Foundation
import Supabase
import CoreLocation

final class SupabaseTrackingRepositoryImpl: TrackingRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    nonisolated func appendPoint(_ point: LocationPoint) async throws {
        // 推荐走 RPC，确保只能已接单司机写
        struct RPCParams: Encodable, Sendable {
            let p_order_id: String
            let p_lat: Double
            let p_lng: Double
        }
        
        let params = RPCParams(
            p_order_id: point.orderId.uuidString,
            p_lat: point.coordinate.latitude,
            p_lng: point.coordinate.longitude
        )
        
        _ = try await client
            .rpc("append_my_order_location", params: params)
            .execute()
    }

    func getPoints(orderId: UUID) async throws -> [LocationPoint] {
        struct Row: Decodable {
            let id: UUID
            let order_id: UUID
            let driver_id: UUID
            let lat: Double
            let lng: Double
            let recorded_at: Date
        }

        let rows: [Row] = try await client
            .from("order_locations")
            .select()
            .eq("order_id", value: orderId.uuidString)
            .order("recorded_at", ascending: true)
            .execute()
            .value

        return rows.map {
            LocationPoint(
                id: $0.id,
                orderId: $0.order_id,
                driverId: $0.driver_id,
                coordinate: .init(latitude: $0.lat, longitude: $0.lng),
                recordedAt: $0.recorded_at
            )
        }
    }
}
