import SwiftUI
import CoreLocation

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
            ZStack(alignment: .top) {

                ScrollView {
                    VStack(spacing: 14) {
                        if let order = vm.currentOrder {
                            statusHero(order)
                            statusPhasePanel(order)
                            trackSection(order)
                        } else {
                            emptyState
                        }
                    }
                    .padding()
                }

                if let msg = vm.errorMessage, !msg.isEmpty {
                    ErrorBanner(message: msg) {
                        withAnimation { vm.errorMessage = nil }
                    }
                    .padding(.top, 6)
                }
            }
            .navigationTitle("我的行程")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await vm.loadLatestOrder()
                            await vm.loadPointsIfNeeded()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("刷新行程")
                }
            }
            .onAppear { vm.onAppear() }
            .onDisappear { vm.onDisappear() }
        }
    }

    // MARK: - UI blocks

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "car")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("暂无订单")
                .font(.headline)
            Text("去乘客页点击「一键下单」")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statusHero(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前订单状态")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(order.status.displayText)
                    .font(.title2).bold()
                Spacer()
                Text(order.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            orderProgressBar(status: order.status)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statusPhasePanel(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("阶段指引")
                .font(.headline)

            Text(phaseDescription(for: order.status))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    Task { await vm.advanceStatus() }
                } label: {
                    Label(nextActionTitle(for: order.status), systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isFinal(status: order.status))

                Spacer()

                if isFinal(status: order.status) {
                    Text("行程已结束")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func trackSection(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("司机轨迹")
                    .font(.headline)
                Spacer()
                Text("\(vm.points.count) 点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if vm.points.isEmpty {
                Text("暂无轨迹点（司机端上报后会自动出现）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(vm.points) { p in
                    HStack {
                        Text(p.recordedAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.5f, %.5f",
                                    p.coordinate.latitude, p.coordinate.longitude))
                            .font(.caption2)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Progress UI

    private func orderProgressBar(status: OrderStatus) -> some View {
        let steps: [OrderStatus] = [.requested, .accepted, .arrived, .started, .completed]
        let currentIndex = steps.firstIndex(of: status) ?? 0

        return HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .frame(height: 6)
                    .opacity(i <= currentIndex ? 1 : 0.25)
            }
        }
    }

    // MARK: - Copy

    private func phaseDescription(for status: OrderStatus) -> String {
        switch status {
        case .requested:
            return "订单已发出，等待附近司机接单。"
        case .accepted:
            return "司机已接单，正在前往上车点。"
        case .arrived:
            return "司机已到达上车点，你可以准备上车。"
        case .started:
            return "行程进行中，可在此查看司机实时位置与轨迹。"
        case .completed:
            return "行程已完成，后续可扩展支付与评价。"
        case .cancelled:
            return "订单已取消。"
        }
    }

    private func nextActionTitle(for status: OrderStatus) -> String {
        switch status {
        case .requested: return "模拟：已接单"
        case .accepted: return "模拟：已到达"
        case .arrived: return "模拟：开始行程"
        case .started: return "模拟：完成行程"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
    }

    private func isFinal(status: OrderStatus) -> Bool {
        status == .completed || status == .cancelled
    }
}
