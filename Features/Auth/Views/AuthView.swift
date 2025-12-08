import SwiftUI
import Supabase

struct AuthView: View {
    let container: AppContainer
    var onAuthed: () -> Void

    @StateObject private var vm: AuthVM
    @State private var showOTPEntry = false

    init(container: AppContainer, onAuthed: @escaping () -> Void) {
        self.container = container
        self.onAuthed = onAuthed

        // 取出你 DefaultSupabaseClientProvider 的 client
        // 如果你没把 client 暴露在 container，就临时再建一个 Provider
        let provider = DefaultSupabaseClientProvider()
        _vm = StateObject(wrappedValue: AuthVM(client: provider.client, authRepo: container.authRepo))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("模式", selection: $vm.mode) {
                    Text("登录").tag(AuthVM.Mode.login)
                    Text("注册").tag(AuthVM.Mode.register)
                }
                .pickerStyle(.segmented)

                Picker("方式", selection: $vm.method) {
                    Text("邮箱密码").tag(AuthVM.Method.emailPassword)
                    Text("手机号验证码").tag(AuthVM.Method.phoneOTP)
                }
                .pickerStyle(.segmented)

                Picker("身份", selection: $vm.role) {
                    Text("我是乘客").tag(AuthVM.RolePick.passenger)
                    Text("我是司机").tag(AuthVM.RolePick.driver)
                }
                .pickerStyle(.segmented)

                Group {
                    if vm.method == .emailPassword {
                        TextField("邮箱", text: $vm.email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textFieldStyle(.roundedBorder)

                        SecureField("密码", text: $vm.password)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Task {
                                if vm.mode == .register {
                                    await vm.signUpEmail()
                                } else {
                                    await vm.signInEmail()
                                }
                                if container.authRepo.currentUser != nil {
                                    onAuthed()
                                }
                            }
                        } label: {
                            Text(vm.mode == .register ? "注册并进入" : "登录并进入")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        TextField("手机号（含国家码）", text: $vm.phone)
                            .keyboardType(.phonePad)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Task {
                                await vm.sendPhoneOTP()
                                if vm.errorMessage == nil {
                                    showOTPEntry = true
                                }
                            }
                        } label: {
                            Text("发送验证码")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let msg = vm.errorMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("注册 / 登录")
            .overlay {
                if vm.isLoading {
                    ProgressView("处理中…")
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationDestination(isPresented: $showOTPEntry) {
                VerifyOTPView(vm: vm) {
                    onAuthed()
                }
            }
        }
    }
}
