import Foundation
import CoreLocation
import Supabase

final class SupabaseDriverRepositoryImpl: DriverRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func getOnlineDrivers(near coordinate: CLLocationCoordinate2D) async throws -> [Driver] {
        let rows: [NearbyDriverRow] = try await client
            .rpc("list_nearby_online_drivers", params: [
                "p_lat": coordinate.latitude,
                "p_lng": coordinate.longitude,
                "p_radius_km": 5,
                "p_limit": 50
            ])
            .execute()
            .value

        return rows.compactMap { row in
            guard let lat = row.current_lat, let lng = row.current_lng else { return nil }
            return Driver(
                id: row.driver_id,
                name: row.name ?? "司机",
                isOnline: row.is_online,
                location: .init(latitude: lat, longitude: lng)
            )
        }
    }

    func setOnline(_ online: Bool, driverId: UUID) async throws -> Driver {
        // 推荐走 “我自己” 的 RPC，避免客户端乱写别人
        guard driverId == client.auth.currentUser?.id else {
            throw qcarError.forbidden("只能更新自己的司机状态")
        }

        let my = try await upsertMyState(isOnline: online, coordinate: nil)
        return my
    }

    func updateLocation(_ coordinate: CLLocationCoordinate2D, driverId: UUID) async throws -> Driver {
        guard driverId == client.auth.currentUser?.id else {
            throw qcarError.forbidden("只能更新自己的位置")
        }

        let my = try await upsertMyState(isOnline: true, coordinate: coordinate)
        return my
    }

    func getDriver(by id: UUID) async throws -> Driver? {
        let rows: [DriverRecord] = try await client
            .from("drivers")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        guard let r = rows.first else { return nil }
        guard let lat = r.current_lat, let lng = r.current_lng else {
            return Driver(id: r.id, name: "司机", isOnline: r.is_online,
                          location: .init(latitude: 0, longitude: 0))
        }

        return Driver(
            id: r.id,
            name: "司机",
            isOnline: r.is_online,
            location: .init(latitude: lat, longitude: lng)
        )
    }

    // MARK: - RPC

    nonisolated private func upsertMyState(isOnline: Bool, coordinate: CLLocationCoordinate2D?) async throws -> Driver {
        let lat = coordinate?.latitude ?? 0
        let lng = coordinate?.longitude ?? 0
        
        struct RPCParams: Encodable, Sendable {
            let p_is_online: Bool
            let p_lat: Double
            let p_lng: Double
        }

        let params = RPCParams(
            p_is_online: isOnline,
            p_lat: lat,
            p_lng: lng
        )

        let record: DriverRecord = try await client
            .rpc("upsert_my_driver_state", params: params)
            .execute()
            .value

        let safeLat = record.current_lat ?? lat
        let safeLng = record.current_lng ?? lng

        return Driver(
            id: record.id,
            name: "我",
            isOnline: record.is_online,
            location: .init(latitude: safeLat, longitude: safeLng)
        )
    }
}
