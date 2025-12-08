import Foundation

struct OrderRecord: Decodable {
    let id: UUID
    let passenger_id: UUID
    let driver_id: UUID?
    let pickup_lat: Double
    let pickup_lng: Double
    let dropoff_lat: Double?
    let dropoff_lng: Double?
    let status: String
    let created_at: Date
    let updated_at: Date?
}
