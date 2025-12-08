import Foundation
import CoreLocation

protocol DriverRepository {
    func getOnlineDrivers(near coordinate: CLLocationCoordinate2D) async throws -> [Driver]
    func setOnline(_ online: Bool, driverId: UUID) async throws -> Driver
    func updateLocation(_ coordinate: CLLocationCoordinate2D, driverId: UUID) async throws -> Driver
    func getDriver(by id: UUID) async throws -> Driver?
}
