import SwiftUI

struct RideTrackingView: View {
    let container: AppContainer
    @StateObject private var vm: TrackingVM

    init(container: AppContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: TrackingVM(
            authRepo: container.authRepo,
            orderRepo: container.orderRepo,
            trackingRepo: container.trackingRepo,
            realtime: container.realtime
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.role == .driver {
                    driverTripsBody
                } else {
                    passengerTrackingBody
                }
            }
            .navigationTitle(vm.role == .driver ? "我的接单" : "我的行程")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.loadByRole() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay(alignment: .top) {
                if let msg = vm.errorMessage, !msg.isEmpty {
                    ErrorBanner(message: msg) { vm.errorMessage = nil }
                        .padding(.top, 6)
                }
            }
            .onAppear { vm.onAppear() }
            .onDisappear { vm.onDisappear() }
            .navigationDestination(item: $vm.selectedDriverOrder) { order in
                DriverTripDetailView(order: order)
            }
        }
    }

    // MARK: - Passenger UI (保留你原来的“状态分段体验”)

    private var passengerTrackingBody: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let order = vm.currentOrder {
                    PassengerTrackingSections(order: order, points: vm.points)
                } else {
                    ContentUnavailableView(
                        "暂无订单",
                        systemImage: "car",
                        description: Text("去乘客页点击「一键下单」")
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
    }

    // MARK: - Driver UI

    private var driverTripsBody: some View {
        List {
            Section("进行中") {
                if vm.driverActiveOrders.isEmpty {
                    Text("暂无进行中订单")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.driverActiveOrders) { order in
                        driverOrderRow(order)
                    }
                }
            }

            Section("历史订单") {
                if vm.driverHistoryOrders.isEmpty {
                    Text("暂无历史订单")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.driverHistoryOrders) { order in
                        driverOrderRow(order)
                    }
                }
            }
        }
    }

    private func driverOrderRow(_ order: Order) -> some View {
        Button {
            vm.selectedDriverOrder = order
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("订单 \(order.id.uuidString.prefix(6))")
                        .font(.headline)
                    Spacer()
                    Text(order.status.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(order.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(order.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
