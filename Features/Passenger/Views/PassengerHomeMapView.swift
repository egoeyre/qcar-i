import SwiftUI
import MapKit

struct PassengerHomeMapView: View {
    let container: AppContainer
    
     @Binding var selectedTab: AppTab

    @StateObject private var vm: PassengerHomeVM

    init(container: AppContainer, selectedTab: Binding<AppTab>) {
        self.container = container
        self._selectedTab = selectedTab
        _vm = StateObject(wrappedValue: PassengerHomeVM(
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

                // Map + driver markers
                ZStack(alignment: .bottom) {
                    MapViewAdapter(
                        region: $vm.region,
                        annotations: vm.onlineDrivers.map { .init(coordinate: $0.location) }
                    )

                    passengerBottomPanel
                }

                // Error banner
                if let msg = vm.errorMessage, !msg.isEmpty {
                    ErrorBanner(message: msg) {
                        withAnimation { vm.errorMessage = nil }
                    }
                    .padding(.top, 6)
                }

                // Loading overlay
                if vm.isLoadingDrivers || vm.isCreatingOrder {
                    LoadingOverlay(text: vm.isCreatingOrder ? "正在创建订单…" : "正在加载附近司机…")
                }
            }
            .navigationTitle("乘客叫代驾")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.refreshDrivers() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("刷新附近司机")
                }
            }
            .onAppear {
                container.locationManager.requestPermission()
                container.locationManager.start()
                vm.onAppear()
            }
            .onDisappear {
                vm.onDisappear()
            }
            .alert(vm.suggestionTitle, isPresented: $vm.showTrackingSuggestion) {
                Button("查看行程") {
                    selectedTab = .tracking
                }
                Button("稍后") { }
            } message: {
                Text(vm.suggestionMessage)
            }
        }
    }

    // MARK: - UI

    private var passengerBottomPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    Task { await vm.refreshDrivers() }
                } label: {
                    Label("刷新附近司机", systemImage: "location.viewfinder")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    Task { await vm.createOrderDemo() }
                } label: {
                    Label("一键下单", systemImage: "car.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            if let order = vm.latestOrder {
                orderStatusCard(order)
            } else {
                hintCard("还没有订单", subtitle: "点击「一键下单」体验完整流程")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding()
    }

        private func orderStatusCard(_ order: Order) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("当前订单")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(order.status.displayText)
                        .font(.headline)
                    Spacer()
                    Text(order.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(passengerHintText(for: order.status))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        private func passengerHintText(for status: OrderStatus) -> String {
            switch status {
            case .requested:
                return "已为你呼叫附近司机，请稍候接单。"
            case .accepted:
                return "司机已接单，正在赶来上车点。"
            case .arrived:
                return "司机已到达，建议进入行程页确认上车。"
            case .started:
                return "行程进行中，可在行程页查看轨迹。"
            case .completed:
                return "行程已完成（可扩展支付/评价）。"
            case .cancelled:
                return "订单已取消。"
            }
        }


    private func hintCard(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
