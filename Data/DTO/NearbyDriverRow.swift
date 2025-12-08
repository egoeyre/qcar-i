import Foundation

struct NearbyDriverRow: Decodable {
    let driver_id: UUID
    let name: String?
    let is_online: Bool
    let current_lat: Double?
    let current_lng: Double?
    let distance_km: Double?
}
