import Foundation
import CoreLocation

protocol OrderRepository {
    func createOrder(passengerId: UUID, pickup: CLLocationCoordinate2D, dropoff: CLLocationCoordinate2D?) async throws -> Order
    func getPassengerOrders(passengerId: UUID) async throws -> [Order]
    func getNearbyOpenOrders(near coordinate: CLLocationCoordinate2D) async throws -> [Order]
    func acceptOrder(orderId: UUID, driverId: UUID) async throws -> Order
    func updateStatus(orderId: UUID, status: OrderStatus) async throws -> Order
    func getOrder(by id: UUID) async throws -> Order?
}
