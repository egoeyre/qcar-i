import Foundation
import CoreLocation

struct LocationPoint: Identifiable, Codable, Equatable {
    let id: UUID
    let orderId: UUID
    let driverId: UUID
    let coordinate: CLLocationCoordinate2D
    let recordedAt: Date

    init(
        id: UUID = UUID(),
        orderId: UUID,
        driverId: UUID,
        coordinate: CLLocationCoordinate2D,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.orderId = orderId
        self.driverId = driverId
        self.coordinate = coordinate
        self.recordedAt = recordedAt
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, orderId, driverId, latitude, longitude, recordedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        orderId = try container.decode(UUID.self, forKey: .orderId)
        driverId = try container.decode(UUID.self, forKey: .driverId)
        let latitude = try container.decode(CLLocationDegrees.self, forKey: .latitude)
        let longitude = try container.decode(CLLocationDegrees.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderId, forKey: .orderId)
        try container.encode(driverId, forKey: .driverId)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(recordedAt, forKey: .recordedAt)
    }
    
    // MARK: - Equatable
    static func == (lhs: LocationPoint, rhs: LocationPoint) -> Bool {
        lhs.id == rhs.id &&
        lhs.orderId == rhs.orderId &&
        lhs.driverId == rhs.driverId &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.recordedAt == rhs.recordedAt
    }
}
