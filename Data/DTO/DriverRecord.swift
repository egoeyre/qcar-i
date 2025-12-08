import Foundation

struct DriverRecord: Decodable {
    let id: UUID
    let is_online: Bool
    let current_lat: Double?
    let current_lng: Double?
    let updated_at: Date?
}
