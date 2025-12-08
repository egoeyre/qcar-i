import Foundation
import CoreLocation

protocol RoutePlanner {
    func estimateDistanceKm(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double
}

struct SimpleRoutePlanner: RoutePlanner {
    func estimateDistanceKm(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let a = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let b = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return a.distance(from: b) / 1000.0
    }
}
