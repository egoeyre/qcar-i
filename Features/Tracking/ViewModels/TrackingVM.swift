import Foundation
import CoreLocation
import Combine

@MainActor
final class TrackingVM: ObservableObject {
    // Passenger mode
    @Published var currentOrder: Order?
    @Published var points: [LocationPoint] = []

    // Driver mode
    @Published var driverOrders: [Order] = []
    @Published var selectedDriverOrder: Order?

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
        let tasks = realtimeTasks
        Task {
            tasks.forEach { $0.cancel() }
        }
    }

    // MARK: - Role

    var role: UserRole {
        authRepo.currentUser?.role ?? .passenger
    }

    private var myId: UUID? {
        authRepo.currentUser?.id
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await loadByRole() }
        startRealtime()
    }

    func onDisappear() {
        stopRealtime()
    }

    // MARK: - Loaders

    func loadByRole() async {
        switch role {
        case .passenger:
            await loadLatestPassengerOrder()
            await loadPointsIfNeeded()
        case .driver:
            await loadDriverOrders()
        }
    }

    // Passenger
    func loadLatestPassengerOrder() async {
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

    // Driver
    func loadDriverOrders() async {
        guard let id = myId else { return }

        guard let impl = orderRepo as? SupabaseOrderRepositoryImpl else {
            driverOrders = []
            return
        }

        do {
            driverOrders = try await impl.getMyDriverOrders(driverId: id)
        } catch {
            errorMessage = error.localizedDescription
            driverOrders = []
        }
    }

    // MARK: - Passenger Actions (保留你原有的推进)

    func advanceStatus() async {
        guard role == .driver else {
            errorMessage = "乘客端不支持推进状态"
            return
        }
        guard let order = currentOrder else { return }

        if order.status == .completed || order.status == .cancelled {
            return
        }

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

    // MARK: - Realtime

    private func startRealtime() {
        guard realtimeTasks.isEmpty else { return }

        let t1 = Task { [weak self] in
            guard let self else { return }
            let stream = await self.realtime.ordersChangeStream()
            for await _ in stream {
                await self.loadByRole()
            }
        }

        let t2 = Task { [weak self] in
            guard let self else { return }
            let stream = await self.realtime.orderLocationsChangeStream()
            for await _ in stream {
                if self.role == .passenger {
                    await self.loadPointsIfNeeded()
                }
            }
        }

        realtimeTasks = [t1, t2]
    }

    private func stopRealtime() {
        realtimeTasks.forEach { $0.cancel() }
        realtimeTasks.removeAll()
    }

    // MARK: - Driver helpers

    var driverActiveOrders: [Order] {
        driverOrders.filter { !isFinal($0.status) }
    }

    var driverHistoryOrders: [Order] {
        driverOrders.filter { isFinal($0.status) }
    }

    private func isFinal(_ status: OrderStatus) -> Bool {
        status == .completed || status == .cancelled
    }
}
