import SwiftUI

public struct VoiceLicenseModalView: View {
    @ObservedObject var licenseService = LicenseService.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var inputKey: String = ""
    @State private var serverUrl: String = LicenseService.defaultServerUrl
    @State private var showServerConfig: Bool = false
    @State private var isProcessing: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var isCopied: Bool = false

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header Icon & Title
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 64, height: 64)
                            Image(systemName: "mic.badge.shield.check")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("Bản Quyền Giọng Nói")
                            .font(.title2.bold())
                        Text("Mỗi máy cần một Key riêng được hệ thống sinh ra theo mã phần cứng độc bản.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)

                    // 1. Khung Thông Tin Máy (Không thể bypass)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "iphone.gen3")
                                .foregroundColor(.blue)
                            Text("THIẾT BỊ NÀY")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(DeviceIdentityService.shared.getDeviceModelName())
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                        }

                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Thiết bị đã được tự động định danh phần cứng trên hệ thống. Admin có sẵn Key kích hoạt cho máy này.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)

                    // 2. Trạng Thái Bản Quyền & Thời Gian Chi Tiết
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("TRẠNG THÁI HIỆN TẠI")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()

                            if licenseService.isVoiceUnlocked {
                                Text("ĐANG HOẠT ĐỘNG")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(8)
                            } else {
                                Text(licenseService.remainingTimeText.contains("hết hạn") ? "ĐÃ HẾT HẠN" : "CHƯA KÍCH HOẠT")
                                    .font(.caption.bold())
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }

                        Divider()

                        if let regDate = licenseService.registeredAtDate {
                            HStack {
                                Text("Ngày Đăng Ký:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(licenseService.formatDate(regDate))
                                    .font(.subheadline.bold())
                            }
                        }

                        if let expDate = licenseService.expiresAtDate {
                            HStack {
                                Text("Ngày Hết Hạn:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(licenseService.isLifetime ? "Vĩnh viễn" : licenseService.formatDate(expDate))
                                    .font(.subheadline.bold())
                                    .foregroundColor(licenseService.isVoiceUnlocked ? .primary : .red)
                            }
                        }

                        HStack {
                            Text("Thời Gian Còn Lại:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(licenseService.remainingTimeText)
                                .font(.subheadline.bold())
                                .foregroundColor(licenseService.isVoiceUnlocked ? .green : .red)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)

                    // 3. Nhập Key Kích Hoạt / Gia Hạn (Cực kỳ dễ dùng)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(licenseService.isVoiceUnlocked ? "GIA HẠN THÊM THỜI GIAN" : "KÍCH HOẠT BẢN QUYỀN")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        Text(licenseService.isVoiceUnlocked
                             ? "Nhập Key gia hạn do Admin cấp. Thời gian mới sẽ tự động được cộng dồn vào hạn hiện tại."
                             : "Dán Key kích hoạt do Admin cấp vào ô dưới và bấm Kích Hoạt (yêu cầu bật mạng lần đầu).")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("VOX-XXXX-YYYY-ZZZZ-WWWW", text: $inputKey)
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .padding(10)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)

                            if UIPasteboard.general.hasStrings {
                                Button(action: {
                                    if let str = UIPasteboard.general.string {
                                        inputKey = str.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                    }
                                }) {
                                    Text("Dán")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.12))
                                        .cornerRadius(8)
                                }
                            }
                        }

                        Button(action: handleActivateOrRenew) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(licenseService.isVoiceUnlocked ? "Gia Hạn Ngay (Cộng Dồn)" : "Kích Hoạt Ngay")
                                    .fontWeight(.bold)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(
                                inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.green, Color.teal], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(12)
                        }
                        .disabled(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)

                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Chỉ cần bật mạng khi bấm Kích Hoạt / Gia Hạn. Sau đó sử dụng Offline 100%.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)

                    // Cấu hình Server (Ẩn, chỉ mở khi cần)
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: { showServerConfig.toggle() }) {
                            HStack {
                                Text(showServerConfig ? "Ẩn cấu hình máy chủ" : "Tùy chỉnh máy chủ (Server URL)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: showServerConfig ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if showServerConfig {
                            TextField("http://157.66.100.10:4000", text: $serverUrl)
                                .font(.caption)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 4)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
            }
            .navigationBarTitle("Bản Quyền Giọng Nói", displayMode: .inline)
            .navigationBarItems(trailing: Button("Đóng") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func handleActivateOrRenew() {
        let cleanKey = inputKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanKey.isEmpty else { return }

        isProcessing = true

        if licenseService.isVoiceUnlocked {
            // Gia hạn
            licenseService.renewWithKey(serverUrl: serverUrl, renewKey: cleanKey) { result in
                isProcessing = false
                switch result {
                case .success(let msg):
                    alertTitle = "Thành Công"
                    alertMessage = msg
                    showAlert = true
                    inputKey = ""
                case .failure(let error):
                    alertTitle = "Gia Hạn Thất Bại"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        } else {
            // Kích hoạt lần đầu
            licenseService.activateWithKey(serverUrl: serverUrl, licenseKey: cleanKey) { result in
                isProcessing = false
                switch result {
                case .success(let msg):
                    alertTitle = "Kích Hoạt Thành Công"
                    alertMessage = "\(msg)\nBây giờ bạn có thể tắt mạng và sử dụng Giọng Nói hoàn toàn Offline."
                    showAlert = true
                    inputKey = ""
                case .failure(let error):
                    alertTitle = "Kích Hoạt Thất Bại"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}
