import SwiftUI

struct DriverCurrentOrderView: View {
    let container: AppContainer
    @Binding var isPresented: Bool          // ✅ 新增：用于返回列表
    @State var order: Order

    var onCompleted: (() -> Void)? = nil    // ✅ 新增：通知首页刷新

    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("当前进行中订单")
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

                Text("上车点：已记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 10) {
                Button {
                    Task { await update(.arrived) }
                } label: {
                    Label("我已到达", systemImage: "figure.stand")
                }
                .buttonStyle(.bordered)
                .disabled(order.status != .accepted)

                Button {
                    Task { await update(.started) }
                } label: {
                    Label("开始行程", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(order.status != .arrived)
            }

            Button {
                Task { await update(.completed) }
            } label: {
                Label("完成行程", systemImage: "checkmark.seal.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(order.status != .started)

            Spacer()
        }
        .padding()
        .navigationTitle("当前订单")
        .overlay(alignment: .top) {
            if let msg = errorMessage {
                ErrorBanner(message: msg) { errorMessage = nil }
                    .padding(.top, 6)
            }
        }
    }

    private func update(_ status: OrderStatus) async {
        do {
            let updated = try await container.orderRepo.updateStatus(orderId: order.id, status: status)
            order = updated

            // ✅ 关键：完成行程后回到接单列表
            if status == .completed {
                onCompleted?()
                isPresented = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
