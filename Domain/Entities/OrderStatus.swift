import Foundation

enum OrderStatus: String, Codable, CaseIterable {
    case requested
    case accepted
    case arrived
    case started
    case completed
    case cancelled

    var displayText: String {
        switch self {
        case .requested: return "已发单"
        case .accepted: return "已接单"
        case .arrived: return "已到达"
        case .started: return "行程中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
    }
}
