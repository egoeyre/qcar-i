import Foundation
import CoreLocation
import Combine
@MainActor
final class TrackingVM: ObservableObject {
    @Published var currentOrder: Order?
    @Published var points: [LocationPoint] = []
    @Published var errorMessage: String?

    private let authRepo: AuthRepository
    private let orderRepo: OrderRepository
    private let trackingRepo: TrackingRepository
    private let realtime: RealtimeBroker

    private var realtimeTasks: [Task<Void, Never>] = []

    init(
        authRepo: AuthRepository,
        orderRepo: OrderRepository,
        trackingRepo: TrackingRepository,
        realtime: RealtimeBroker
    ) {
        self.authRepo = authRepo
        self.orderRepo = orderRepo
        self.trackingRepo = trackingRepo
        self.realtime = realtime
    }

    deinit {
        // Cancel tasks directly since deinit cannot be async or actor-isolated
        realtimeTasks.forEach { $0.cancel() }
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await loadLatestOrder() }
        Task { await loadPointsIfNeeded() }
        startRealtime()
    }

    func onDisappear() {
        stopRealtime()
    }

    // MARK: - Queries

    func loadLatestOrder() async {
        guard let user = authRepo.currentUser else { return }

        do {
            let orders = try await orderRepo.getPassengerOrders(passengerId: user.id)
            currentOrder = orders.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPointsIfNeeded() async {
        guard let order = currentOrder else { return }
        do {
            points = try await trackingRepo.getPoints(orderId: order.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Actions

    func advanceStatus() async {
        guard let order = currentOrder else { return }

        let next = nextStatus(after: order.status)

        do {
            currentOrder = try await orderRepo.updateStatus(orderId: order.id, status: next)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func nextStatus(after status: OrderStatus) -> OrderStatus {
        switch status {
        case .requested: return .accepted
        case .accepted: return .arrived
        case .arrived: return .started
        case .started: return .completed
        case .completed: return .completed
        case .cancelled: return .cancelled
        }
    }

    // 司机端调用这个的真实写点在 TrackingRepositoryImpl 里
    func appendPointAsDriver(_ coordinate: CLLocationCoordinate2D) async {
        guard let order = currentOrder,
              let driverId = order.driverId else { return }

        let p = LocationPoint(orderId: order.id, driverId: driverId, coordinate: coordinate)

        do {
            try await trackingRepo.appendPoint(p)
            points = try await trackingRepo.getPoints(orderId: order.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Realtime

    private func startRealtime() {
        guard realtimeTasks.isEmpty else { return }

        // 订单状态/司机分配变化 → 刷新当前订单
        let t1 = Task { [weak self] in
            guard let self else { return }
            let stream = await self.realtime.ordersChangeStream()
            for await _ in stream {
                await self.loadLatestOrder()
                await self.loadPointsIfNeeded()
            }
        }

        // 轨迹表新增 → 刷新轨迹
        let t2 = Task { [weak self] in
            guard let self else { return }
            let stream = await self.realtime.orderLocationsChangeStream()
            for await _ in stream {
                await self.loadPointsIfNeeded()
            }
        }

        realtimeTasks = [t1, t2]
    }

    private func stopRealtime() {
        realtimeTasks.forEach { $0.cancel() }
        realtimeTasks.removeAll()
    }
}
