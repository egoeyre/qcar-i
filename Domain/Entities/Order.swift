import Foundation
import CoreLocation

struct Order: Identifiable, Codable, Equatable {
    let id: UUID
    let passengerId: UUID
    var driverId: UUID?

    var pickup: CLLocationCoordinate2D
    var dropoff: CLLocationCoordinate2D?

    var status: OrderStatus
    let createdAt: Date

    init(
        id: UUID = UUID(),
        passengerId: UUID,
        driverId: UUID? = nil,
        pickup: CLLocationCoordinate2D,
        dropoff: CLLocationCoordinate2D? = nil,
        status: OrderStatus = .requested,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.passengerId = passengerId
        self.driverId = driverId
        self.pickup = pickup
        self.dropoff = dropoff
        self.status = status
        self.createdAt = createdAt
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, passengerId, driverId, pickup, dropoff, status, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        passengerId = try container.decode(UUID.self, forKey: .passengerId)
        driverId = try container.decodeIfPresent(UUID.self, forKey: .driverId)
        status = try container.decode(OrderStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Decode CLLocationCoordinate2D from lat/lon
        let pickupData = try container.decode([String: Double].self, forKey: .pickup)
        pickup = CLLocationCoordinate2D(
            latitude: pickupData["latitude"] ?? 0,
            longitude: pickupData["longitude"] ?? 0
        )
        
        if let dropoffData = try container.decodeIfPresent([String: Double].self, forKey: .dropoff) {
            dropoff = CLLocationCoordinate2D(
                latitude: dropoffData["latitude"] ?? 0,
                longitude: dropoffData["longitude"] ?? 0
            )
        } else {
            dropoff = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(passengerId, forKey: .passengerId)
        try container.encodeIfPresent(driverId, forKey: .driverId)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        
        // Encode CLLocationCoordinate2D as lat/lon dictionary
        try container.encode([
            "latitude": pickup.latitude,
            "longitude": pickup.longitude
        ], forKey: .pickup)
        
        if let dropoff = dropoff {
            try container.encode([
                "latitude": dropoff.latitude,
                "longitude": dropoff.longitude
            ], forKey: .dropoff)
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Order, rhs: Order) -> Bool {
        lhs.id == rhs.id &&
        lhs.passengerId == rhs.passengerId &&
        lhs.driverId == rhs.driverId &&
        lhs.pickup.latitude == rhs.pickup.latitude &&
        lhs.pickup.longitude == rhs.pickup.longitude &&
        lhs.dropoff?.latitude == rhs.dropoff?.latitude &&
        lhs.dropoff?.longitude == rhs.dropoff?.longitude &&
        lhs.status == rhs.status &&
        lhs.createdAt == rhs.createdAt
    }
}
