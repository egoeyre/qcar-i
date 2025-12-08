import Foundation
import CoreLocation
import MapKit
import Combine

@MainActor
final class PassengerHomeVM: ObservableObject {
    // UI State
    @Published var region: MKCoordinateRegion
    @Published var onlineDrivers: [Driver] = []
    @Published var latestOrder: Order?
    @Published var isLoadingDrivers = false
    @Published var isCreatingOrder = false
    @Published var errorMessage: String?
    //增加“推荐跳转”状态
    @Published var showTrackingSuggestion = false
    @Published var suggestionTitle: String = ""
    @Published var suggestionMessage: String = ""

    // Deps
    private let driverRepo: DriverRepository
    private let orderRepo: OrderRepository
    private let authRepo: AuthRepository
    private let realtime: RealtimeBroker
    private let locationManager: LocationManager

    private var realtimeTasks: [Task<Void, Never>] = []

    private var lastSuggestedOrderId: UUID?
    private var lastSuggestedStatus: OrderStatus?

    init(
        authRepo: AuthRepository,
        driverRepo: DriverRepository,
        orderRepo: OrderRepository,
        realtime: RealtimeBroker,
        locationManager: LocationManager
    ) {
        self.authRepo = authRepo
        self.driverRepo = driverRepo
        self.orderRepo = orderRepo
        self.realtime = realtime
        self.locationManager = locationManager

        let defaultCenter = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        self.region = MKCoordinateRegion(
            center: defaultCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    deinit {
        for task in realtimeTasks {
            task.cancel()
        }
    }

    // MARK: - Lifecycle

    func onAppear() {
        locationManager.requestPermission()
        locationManager.start()

        // 尽量用真实定位作为 region center
        if let c = locationManager.lastCoordinate {
            region.center = c
        }

        Task { await ensurePassengerSession() }
        Task { await refreshDrivers() }
        Task { await loadLatestOrder() }

        startRealtime()
    }

    func onDisappear() {
        stopRealtime()
    }

    // MARK: - Auth

    private func ensurePassengerSession() async {
        do {
            if authRepo.currentUser == nil {
                _ = try await authRepo.signInAsPassenger()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Queries

    func refreshDrivers() async {
        isLoadingDrivers = true
        defer { isLoadingDrivers = false }

        do {
            let center = locationManager.lastCoordinate ?? region.center
            onlineDrivers = try await driverRepo.getOnlineDrivers(near: center)
        } catch {
            onlineDrivers = []
            errorMessage = error.localizedDescription
        }
    }

    func loadLatestOrder() async {
        guard let user = authRepo.currentUser else { return }
        do {
            let orders = try await orderRepo.getPassengerOrders(passengerId: user.id)
            latestOrder = orders.first
            evaluateTrackingSuggestion()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Actions

    /// MVP 简化：用当前地图中心作为上车点
    func createOrderDemo() async {
        guard let user = authRepo.currentUser else {
            errorMessage = "请先登录"
            return
        }

        isCreatingOrder = true
        defer { isCreatingOrder = false }

        let pickup = locationManager.lastCoordinate ?? region.center
        let dropoff = CLLocationCoordinate2D(
            latitude: pickup.latitude - 0.01,
            longitude: pickup.longitude - 0.01
        )

        do {
            latestOrder = try await orderRepo.createOrder(
                passengerId: user.id,
                pickup: pickup,
                dropoff: dropoff
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Realtime

    private func startRealtime() {
        guard realtimeTasks.isEmpty else { return }

        // 司机变更 → 刷新附近司机
        let t1 = Task { [weak self] in
            guard let self else { return }
            let stream = await realtime.driversChangeStream()
            for await _ in stream {
                await self.refreshDrivers()
            }
        }

        // 订单变更 → 刷新我的最新订单
        let t2 = Task { [weak self] in
            guard let self else { return }
            let stream = await realtime.ordersChangeStream()
            for await _ in stream {
                await self.loadLatestOrder()
            }
        }

        realtimeTasks = [t1, t2]
    }

    private func stopRealtime() {
        realtimeTasks.forEach { $0.cancel() }
        realtimeTasks.removeAll()
    }

    private func evaluateTrackingSuggestion() {
    guard let order = latestOrder else { return }

    // 只对 arrived / started 做“推荐”
    guard order.status == .arrived || order.status == .started else {
        return
    }

    // 避免同一订单同一状态反复弹
    if lastSuggestedOrderId == order.id, lastSuggestedStatus == order.status {
        return
    }

    lastSuggestedOrderId = order.id
    lastSuggestedStatus = order.status

    suggestionTitle = (order.status == .arrived) ? "司机已到达" : "行程进行中"
    suggestionMessage = "建议进入「行程」页面查看实时状态与轨迹。"
    showTrackingSuggestion = true
}

}
