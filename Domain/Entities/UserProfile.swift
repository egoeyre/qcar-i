import Foundation

enum UserRole: String, Codable {
    case passenger
    case driver
}

struct UserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var role: UserRole
    var name: String?
    var phone: String?

    init(id: UUID = UUID(), role: UserRole, name: String? = nil, phone: String? = nil) {
        self.id = id
        self.role = role
        self.name = name
        self.phone = phone
    }
}
