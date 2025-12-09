import SwiftUI

struct DriverTripDetailView: View {
    let order: Order

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("订单详情")
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
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text("订单号")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(order.id.uuidString)
                    .font(.footnote)
                    .textSelection(.enabled)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Spacer()
        }
        .padding()
        .navigationTitle("订单 \(order.id.uuidString.prefix(6))")
    }
}
