import Foundation
import CoreLocation

struct Driver: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isOnline: Bool
    var location: CLLocationCoordinate2D

    init(
        id: UUID = UUID(),
        name: String,
        isOnline: Bool = false,
        location: CLLocationCoordinate2D
    ) {
        self.id = id
        self.name = name
        self.isOnline = isOnline
        self.location = location
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, name, isOnline, latitude, longitude
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isOnline = try container.decode(Bool.self, forKey: .isOnline)
        let latitude = try container.decode(CLLocationDegrees.self, forKey: .latitude)
        let longitude = try container.decode(CLLocationDegrees.self, forKey: .longitude)
        location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encode(location.latitude, forKey: .latitude)
        try container.encode(location.longitude, forKey: .longitude)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Driver, rhs: Driver) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.isOnline == rhs.isOnline &&
        lhs.location.latitude == rhs.location.latitude &&
        lhs.location.longitude == rhs.location.longitude
    }
}
