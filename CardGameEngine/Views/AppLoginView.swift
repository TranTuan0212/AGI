import SwiftUI

public struct AppLoginView: View {
    @ObservedObject var authManager = AppAuthManager.shared

    @State private var usernameInput: String = ""
    @State private var passwordInput: String = ""
    @State private var showPassword: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Nền tối Obsidian hoàng gia sang trọng
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.08, blue: 0.06),
                    Color(red: 0.05, green: 0.04, blue: 0.03),
                    Color(red: 0.02, green: 0.02, blue: 0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 24) {
                    // Header Thương hiệu: AceAnalytics Master
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.85, green: 0.60, blue: 0.15),
                                            Color(red: 0.98, green: 0.80, blue: 0.30),
                                            Color(red: 0.70, green: 0.45, blue: 0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 76, height: 76)
                                .shadow(color: Color.yellow.opacity(0.35), radius: 16, x: 0, y: 8)

                            Image(systemName: "suit.spade.fill")
                                .font(.system(size: 38, weight: .black))
                                .foregroundColor(Color(red: 0.08, green: 0.06, blue: 0.04))
                        }

                        Text("AceAnalytics")
                            .font(.system(size: 28, weight: .black, design: .serif))
                            .foregroundColor(Color(red: 0.98, green: 0.85, blue: 0.45))

                        Text("Master Tactical Intelligence Engine")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.amberAccent)
                            .tracking(1.5)

                        Text("Nền Tảng Đánh Giá & Phân Tích Thể Thao Trí Tuệ")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 40)

                    // Báo lỗi nếu có
                    if let err = authManager.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    }

                    // Form Đăng Nhập
                    VStack(spacing: 16) {
                        // Tài khoản
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tài khoản Thành viên:")
                                .font(.caption.bold())
                                .foregroundColor(.gray)

                            HStack {
                                Image(systemName: "person.badge.shield.checkmark.fill")
                                    .foregroundColor(Color(red: 0.90, green: 0.70, blue: 0.20))
                                    .frame(width: 24)

                                TextField("Nhập tên tài khoản...", text: $usernameInput)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.90, green: 0.70, blue: 0.20).opacity(0.25), lineWidth: 1)
                            )
                        }

                        // Mật khẩu
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mã bảo mật (Mật khẩu):")
                                .font(.caption.bold())
                                .foregroundColor(.gray)

                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(Color(red: 0.90, green: 0.70, blue: 0.20))
                                    .frame(width: 24)

                                if showPassword {
                                    TextField("Nhập mật khẩu...", text: $passwordInput)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .foregroundColor(.white)
                                } else {
                                    SecureField("Nhập mật khẩu...", text: $passwordInput)
                                        .foregroundColor(.white)
                                }

                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.90, green: 0.70, blue: 0.20).opacity(0.25), lineWidth: 1)
                            )
                        }

                        // Nút Đăng Nhập
                        Button(action: handleLogin) {
                            HStack(spacing: 8) {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Image(systemName: "lock.open.fill")
                                    Text("TRUY CẬP HỆ THỐNG")
                                        .fontWeight(.black)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(Color(red: 0.10, green: 0.08, blue: 0.04))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.85, green: 0.60, blue: 0.15),
                                        Color(red: 0.98, green: 0.80, blue: 0.30),
                                        Color(red: 0.80, green: 0.55, blue: 0.10)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: Color.yellow.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(authManager.isLoading || usernameInput.isEmpty || passwordInput.isEmpty)
                        .opacity((authManager.isLoading || usernameInput.isEmpty || passwordInput.isEmpty) ? 0.6 : 1.0)
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(red: 0.90, green: 0.70, blue: 0.20).opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Định danh phần cứng mã hóa (Zero-Leak Device Shield)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                                .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.15))
                            Text("Định danh phần cứng bảo mật:")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                            Spacer()
                            Text(DeviceIdentityService.shared.getDeviceModelName())
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }

                        Text("Phiên làm việc được mã hóa độc quyền theo cấu trúc phần cứng di động. Mỗi tài khoản được liên kết độc lập, không cho phép chia sẻ.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func handleLogin() {
        authManager.serverURL = AppAuthManager.defaultServerURL
        authManager.login(username: usernameInput, password: passwordInput) { success in
            if success {
                // Đăng nhập thành công, app tự động switch sang ContentView
            }
        }
    }
}

private extension Color {
    static let amberAccent = Color(red: 0.95, green: 0.75, blue: 0.25)
}
