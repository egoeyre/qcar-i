import SwiftUI
import CoreLocation

struct PassengerTrackingSections: View {
    let order: Order
    let points: [LocationPoint]

    var body: some View {
        VStack(spacing: 12) {

            // 状态卡
            VStack(alignment: .leading, spacing: 6) {
                Text("当前订单状态")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(order.status.displayText)
                    .font(.title2).bold()

                Text(passengerHint(for: order.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // 简易进度条（可选）
            progressBar(status: order.status)

            // 轨迹信息
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("司机轨迹")
                        .font(.headline)
                    Spacer()
                    Text("\(points.count) 点")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if points.isEmpty {
                    Text("司机上报位置后会自动显示")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(points) { p in
                        HStack {
                            Text(p.recordedAt, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.5f, %.5f",
                                        p.coordinate.latitude, p.coordinate.longitude))
                                .font(.caption2)
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func passengerHint(for status: OrderStatus) -> String {
        switch status {
        case .requested:
            return "已为你呼叫附近司机，请等待接单。"
        case .accepted:
            return "司机已接单，正在赶来上车点。"
        case .arrived:
            return "司机已到达，请前往上车点。"
        case .started:
            return "行程进行中，可在此查看实时轨迹。"
        case .completed:
            return "行程已完成。"
        case .cancelled:
            return "订单已取消。"
        }
    }

    private func progressBar(status: OrderStatus) -> some View {
        let steps: [OrderStatus] = [.requested, .accepted, .arrived, .started, .completed]
        let idx = steps.firstIndex(of: status) ?? 0

        return HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .frame(height: 6)
                    .opacity(i <= idx ? 1 : 0.25)
            }
        }
        .padding(.horizontal, 2)
    }
}
