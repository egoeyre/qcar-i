import Foundation

protocol TrackingRepository {
    func appendPoint(_ point: LocationPoint) async throws
    func getPoints(orderId: UUID) async throws -> [LocationPoint]
}
