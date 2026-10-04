import SwiftUI

public struct AppLoginView: View {
    @ObservedObject var authManager = AppAuthManager.shared

    @State private var usernameInput: String = ""
    @State private var passwordInput: String = ""
    @State private var showPassword: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Nền tối thanh lịch, chuyên nghiệp
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.09, blue: 0.14), Color(red: 0.04, green: 0.04, blue: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 24) {
                    // Header Ngụy Trang: Voice Entry Pro
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)

                            Image(systemName: "waveform.badge.mic")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("Voice Entry Pro")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("Hệ Thống Ghi Chép & Nhập Liệu Giọng Nói Kỹ Thuật Số")
                            .font(.caption)
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
                            Text("Tài khoản User:")
                                .font(.caption.bold())
                                .foregroundColor(.gray)

                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                TextField("Nhập tên tài khoản...", text: $usernameInput)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }

                        // Mật khẩu
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mật khẩu:")
                                .font(.caption.bold())
                                .foregroundColor(.gray)

                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.purple)
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
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }

                        // Nút Đăng Nhập
                        Button(action: handleLogin) {
                            HStack(spacing: 8) {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("ĐĂNG NHẬP")
                                        .fontWeight(.bold)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(authManager.isLoading || usernameInput.isEmpty || passwordInput.isEmpty)
                        .opacity((authManager.isLoading || usernameInput.isEmpty || passwordInput.isEmpty) ? 0.6 : 1.0)
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Thông tin thiết bị tự định danh (Không thể bypass)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "iphone.gen3")
                                .foregroundColor(.green)
                            Text("Thiết bị tự động định danh:")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                            Spacer()
                            Text(DeviceIdentityService.shared.getDeviceModelName())
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }

                        Text("Mỗi tài khoản được phép sử dụng tối đa 02 máy Nhập. Thiết bị được gán cố định phần cứng và tự sinh Key Giọng Nói trên Server.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.03))
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
