import SwiftUI

struct ProfileView: View {
    let container: AppContainer

    @EnvironmentObject private var session: SessionStore
    @State private var errorMessage: String?
    @State private var isSigningOut = false
    @State private var isSwitchingRole = false

    init(container: AppContainer) {
        self.container = container
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let user = container.authRepo.currentUser {
                        infoRow(title: "身份", value: user.role == .driver ? "司机" : "乘客")
                        infoRow(title: "姓名", value: user.name ?? "未填写")
                        infoRow(title: "手机号", value: user.phone ?? "未填写")
                    } else {
                        Text("未获取到用户信息")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("个人信息")
                }

                Section {
                    Button {
                        Task { await switchRole(.passenger) }
                    } label: {
                        Label("切换为乘客模式", systemImage: "person")
                    }
                    .disabled(isSwitchingRole)

                    Button {
                        Task { await switchRole(.driver) }
                    } label: {
                        Label("切换为司机模式", systemImage: "steeringwheel")
                    }
                    .disabled(isSwitchingRole)
                } header: {
                    Text("身份切换（MVP）")
                } footer: {
                    Text("MVP 阶段通过写 profiles.role 实现。后续可加司机审核开关。")
                }

                if let user = container.authRepo.currentUser, user.role == .driver {
                    Section {
                        Button(role: .none) {
                            Task { await forceDriverOfflineIfNeeded() }
                        } label: {
                            Label("一键下线（安全）", systemImage: "pause.circle")
                        }
                    } header: {
                        Text("司机状态")
                    } footer: {
                        Text("退出前建议先下线，避免误接单。")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await signOut() }
                    } label: {
                        Label("退出登录", systemImage: "arrow.backward.circle")
                    }
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("我的")
            .overlay {
                if isSigningOut || isSwitchingRole {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(isSigningOut ? "正在退出…" : "正在切换身份…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert("提示", isPresented: .constant(errorMessage != nil), actions: {
                Button("知道了") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    // MARK: - UI

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func switchRole(_ role: UserRole) async {
        isSwitchingRole = true
        defer { isSwitchingRole = false }

        do {
            switch role {
            case .passenger:
                _ = try await container.authRepo.signInAsPassenger()
            case .driver:
                _ = try await container.authRepo.signInAsDriver()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func forceDriverOfflineIfNeeded() async {
        guard let user = container.authRepo.currentUser else { return }
        guard user.role == .driver else { return }

        do {
            _ = try await container.driverRepo.setOnline(false, driverId: user.id)
        } catch {
            // 不强制报错，避免影响用户退出
        }
    }

    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }

        // 退出前尽量下线（司机）
        await forceDriverOfflineIfNeeded()

        await container.authRepo.signOut()
        session.markSignedOut()
    }
}
