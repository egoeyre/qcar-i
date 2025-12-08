import Foundation

struct NearbyOrderRow: Decodable {
    let order_id: UUID
    let passenger_id: UUID
    let pickup_lat: Double
    let pickup_lng: Double
    let dropoff_lat: Double?
    let dropoff_lng: Double?
    let status: String
    let distance_km: Double?
    let created_at: Date
}
