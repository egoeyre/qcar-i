import Foundation
import CoreLocation
import Combine
@MainActor
final class DriverHomeVM: ObservableObject {
    @Published var isOnline: Bool = false
    @Published var nearbyOrders: [Order] = []
    @Published var me: Driver?
    @Published var errorMessage: String?

    @Published var currentOrder: Order?
    @Published var shouldNavigateToCurrentOrder = false

    
    @Published var isLoadingOrders = false

    private let authRepo: AuthRepository
    private let driverRepo: DriverRepository
    private let orderRepo: OrderRepository
    private let realtime: RealtimeBroker
    private let locationManager: LocationManager

    private var realtimeTasks: [Task<Void, Never>] = []
    private var heartbeatTask: Task<Void, Never>?

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
    }

    deinit {
        // Cancel tasks directly without going through main actor-isolated methods
        realtimeTasks.forEach { $0.cancel() }
        heartbeatTask?.cancel()
    }

    // MARK: - Lifecycle

    func onAppear() {
        locationManager.requestPermission()
        locationManager.start()

        Task { await ensureDriverSession() }
        
        Task { await loadMyCurrentOrderIfAny() }

        startRealtime()
    }

    func onDisappear() {
        stopRealtime()
        stopHeartbeat()
    }

    // MARK: - Auth

    private func ensureDriverSession() async {
        do {
            if authRepo.currentUser == nil {
                _ = try await authRepo.signInAsDriver()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var myDriverId: UUID? {
        authRepo.currentUser?.id
    }

    // MARK: - Actions

    func toggleOnline() async {
        guard let id = myDriverId else {
            errorMessage = "请先登录"
            return
        }

        let target = !isOnline
        let coord = locationManager.lastCoordinate

        do {
            // setOnline 会走你 driverRepo 的 “upsert_my_driver_state”
            let updated = try await driverRepo.setOnline(target, driverId: id)
            isOnline = updated.isOnline

            // 第一时间也写一次位置
            if let c = coord {
                me = try await driverRepo.updateLocation(c, driverId: id)
            } else {
                me = updated
            }

            if isOnline {
                startHeartbeat()
                await refreshNearbyOrders()
            } else {
                stopHeartbeat()
                nearbyOrders = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshNearbyOrders() async {
        guard isOnline else { return }
        guard let c = locationManager.lastCoordinate else { return }

        isLoadingOrders = true
        defer { isLoadingOrders = false }

        do {
            nearbyOrders = try await orderRepo.getNearbyOpenOrders(near: c)
        } catch {
            nearbyOrders = []
            errorMessage = error.localizedDescription
        }
    }

    func accept(_ order: Order) async {
        guard let id = myDriverId else { return }

        do {
            let accepted = try await orderRepo.acceptOrder(orderId: order.id, driverId: id)
            nearbyOrders.removeAll { $0.id == accepted.id }

            currentOrder = accepted
            shouldNavigateToCurrentOrder = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    // MARK: - Heartbeat (位置心跳)

    private func startHeartbeat() {
        stopHeartbeat()

        heartbeatTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                if !self.isOnline { break }
                guard let id = self.myDriverId else { break }

                if let c = self.locationManager.lastCoordinate {
                    _ = try? await self.driverRepo.updateLocation(c, driverId: id)
                }

                // 3 秒一次够用（MVP）
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    // MARK: - Realtime

    private func startRealtime() {
        guard realtimeTasks.isEmpty else { return }

        // 新订单/订单被别人接走 → 刷新列表
        let t1 = Task { [weak self] in
            guard let self else { return }
            let stream = await self.realtime.ordersChangeStream()
            for await _ in stream {
                await self.refreshNearbyOrders()
                await self.loadMyCurrentOrderIfAny()
            }
        }

        realtimeTasks = [t1]
    }

    private func stopRealtime() {
        realtimeTasks.forEach { $0.cancel() }
        realtimeTasks.removeAll()
    }

    func loadMyCurrentOrderIfAny() async {
        guard let id = myDriverId else { return }

        // 这里用表查询实现“司机当前订单”
        // 只取非终态的最近一单
        do {
            struct Row: Decodable {
                let id: UUID
                let passenger_id: UUID
                let driver_id: UUID?
                let pickup_lat: Double
                let pickup_lng: Double
                let dropoff_lat: Double?
                let dropoff_lng: Double?
                let status: String
                let created_at: Date
            }

            // 需要你在 SupabaseOrderRepositoryImpl 里暴露一个 helper
            // 为了不改协议，这里最简单做法：
            // 直接调用 orderRepo.getOrder(by:) 不够用
            // 所以我们在 VM 里先走“协议内可得的信息”：
            // ✅ 方案：让 orderRepo 增加一个可选扩展函数（见下方 Extension）
        if let impl = orderRepo as? SupabaseOrderRepositoryImpl {
            do {
                let list = try await impl.getMyActiveDriverOrders(driverId: id)
                currentOrder = list.first
            } catch {}
        }
    }
}}
