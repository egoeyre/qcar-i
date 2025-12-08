import SwiftUI

struct VerifyOTPView: View {
    @ObservedObject var vm: AuthVM
    var onAuthed: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("验证码已发送到")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(vm.phone)
                .font(.headline)

            TextField("输入 6 位验证码", text: $vm.otp)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            Button {
                Task {
                    await vm.verifyPhoneOTP()
                    if vm.errorMessage == nil {
                        onAuthed()
                    }
                }
            } label: {
                Text("验证并进入")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let msg = vm.errorMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("验证手机号")
        .overlay {
            if vm.isLoading {
                ProgressView("验证中…")
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
