import Foundation
import Combine

final class AppContainer: ObservableObject {
    // Repositories
    let authRepo: AuthRepository
    let driverRepo: DriverRepository
    let orderRepo: OrderRepository
    let trackingRepo: TrackingRepository

    // Core services (如果你要共享也可以放这里)
    let locationManager: LocationManager
    let realtime: RealtimeBroker

    init(
        authRepo: AuthRepository,
        driverRepo: DriverRepository,
        orderRepo: OrderRepository,
        trackingRepo: TrackingRepository,
        locationManager: LocationManager,
        realtime: RealtimeBroker
    ) {
        self.authRepo = authRepo
        self.driverRepo = driverRepo
        self.orderRepo = orderRepo
        self.trackingRepo = trackingRepo
        self.locationManager = locationManager
        self.realtime = realtime
    }
}

enum AppDI {
    static func makeContainer() -> AppContainer {
        let location = LocationManager()

        // 先用内存实现，保证能跑
        // let auth = InMemoryAuthRepository()
        // let driver = InMemoryDriverRepository()
        // let order = InMemoryOrderRepository(driverRepo: driver)
        // let tracking = InMemoryTrackingRepository()

        let provider = DefaultSupabaseClientProvider()
        let client = provider.client

        let realtime = SupabaseRealtimeBroker(client: client)

        let auth = SupabaseAuthRepositoryImpl(client: client)
        let driver = SupabaseDriverRepositoryImpl(client: client)
        let order = SupabaseOrderRepositoryImpl(client: client)
        let tracking = SupabaseTrackingRepositoryImpl(client: client)


        return AppContainer(
            authRepo: auth,
            driverRepo: driver,
            orderRepo: order,
            trackingRepo: tracking,
            locationManager: location,
            realtime: realtime
        )
    }
}
