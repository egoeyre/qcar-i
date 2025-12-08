import Foundation
import Supabase
import Combine

@MainActor
final class AuthVM: ObservableObject {
    enum Mode { case login, register }
    enum Method { case emailPassword, phoneOTP }
    enum RolePick { case passenger, driver }

    @Published var mode: Mode = .login
    @Published var method: Method = .emailPassword
    @Published var role: RolePick = .passenger

    @Published var email = ""
    @Published var password = ""

    @Published var phone = ""      // 需要带国家码，如 +86...
    @Published var otp = ""

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client: SupabaseClient
    private let authRepo: AuthRepository

    init(client: SupabaseClient, authRepo: AuthRepository) {
        self.client = client
        self.authRepo = authRepo
    }

    // MARK: - Email + Password

    func signUpEmail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await client.auth.signUp(email: email, password: password)

            // ✅ 注册统一默认为乘客
            _ = try await authRepo.signInAsPassenger()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInEmail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await client.auth.signIn(email: email, password: password)  // :contentReference[oaicite:3]{index=3}
            try await setRoleAfterAuth()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Phone OTP

    func sendPhoneOTP() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.auth.signInWithOTP(phone: phone)  // :contentReference[oaicite:4]{index=4}
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyPhoneOTP() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.auth.verifyOTP(phone: phone, token: otp, type: .sms)  // :contentReference[oaicite:5]{index=5}
            _ = try await authRepo.signInAsPassenger()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Role

    private func setRoleAfterAuth() async throws {
        switch role {
        case .passenger:
            _ = try await authRepo.signInAsPassenger()
        case .driver:
            _ = try await authRepo.signInAsDriver()
        }
    }
}
