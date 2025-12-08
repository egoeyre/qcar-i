import SwiftUI

struct DriverHomeView: View {
    let container: AppContainer
    @StateObject private var vm: DriverHomeVM

    init(container: AppContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: DriverHomeVM(
            authRepo: container.authRepo,
            driverRepo: container.driverRepo,
            orderRepo: container.orderRepo,
            realtime: container.realtime,
            locationManager: container.locationManager
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                VStack(spacing: 12) {
                    driverStatusPanel
                    
                    if let current = vm.currentOrder {
                        currentOrderCard(current)
                            .padding(.horizontal)
                    }

                    List {
                        Section {
                            if !vm.isOnline {
                                Text("请先上线接单")
                                    .foregroundStyle(.secondary)
                            } else if vm.nearbyOrders.isEmpty {
                                Text("5km 内暂无可接订单")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(vm.nearbyOrders) { order in
                                    orderRow(order)
                                }
                            }
                        } header: {
                            Text("附近可接订单（5km）")
                        }
                    }
                }

                if let msg = vm.errorMessage, !msg.isEmpty {
                    ErrorBanner(message: msg) {
                        withAnimation { vm.errorMessage = nil }
                    }
                    .padding(.top, 6)
                }

                if vm.isLoadingOrders {
                    LoadingOverlay(text: "正在加载附近订单…")
                }
            }
            .navigationTitle("司机接单")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.refreshNearbyOrders() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!vm.isOnline)
                    .accessibilityLabel("刷新附近订单")
                }
            }
            .onAppear { 
                container.locationManager.requestPermission()
                container.locationManager.start()
                vm.onAppear() 
            }
            .onDisappear { vm.onDisappear() }
            .navigationDestination(isPresented: $vm.shouldNavigateToCurrentOrder) {
                if let order = vm.currentOrder {
                    DriverCurrentOrderView(
                        container: container,
                        isPresented: $vm.shouldNavigateToCurrentOrder,
                        order: order,
                        onCompleted: {
                            // ✅ 通知首页状态收尾
                            vm.currentOrder = nil
                            Task { await vm.refreshNearbyOrders() }
                        }
                    )
                } else {
                    Text("暂无当前订单")
                }
            }
        }
    }

    // MARK: - UI

    private var driverStatusPanel: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("接单状态")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.isOnline ? "在线中" : "离线")
                        .font(.title3).bold()
                }
                Spacer()
                if vm.isOnline {
                    Button {
                        Task { await vm.toggleOnline() }
                    } label: {
                        Label("下线", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        Task { await vm.toggleOnline() }
                    } label: {
                        Label("上线", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.secondary)
                Text(container.locationManager.lastCoordinate != nil ? "定位正常" : "等待定位…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    private func orderRow(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("订单 \(order.id.uuidString.prefix(6))")
                    .font(.headline)
                Spacer()
                Text(order.status.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("上车点：已记录")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    Task { await vm.accept(order) }
                } label: {
                    Label("接单", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Text(order.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func currentOrderCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("我已接订单")
                    .font(.headline)
                Spacer()
                Text(order.status.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("点击进入可推进状态")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                vm.shouldNavigateToCurrentOrder = true
            } label: {
                Label("进入当前订单", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

}
