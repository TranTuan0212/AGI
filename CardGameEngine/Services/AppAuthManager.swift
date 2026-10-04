import Foundation
import UIKit

/// AppAuthManager quản lý xác thực tài khoản trên App Nhập (Voice Entry),
/// định danh phần cứng máy (UUID & Fingerprint) gửi lên Server,
/// và tự động ghi nhớ trạng thái đăng nhập (Auto-login) an toàn qua iOS Keychain.
public class AppAuthManager: ObservableObject {
    public static let shared = AppAuthManager()

    public static let defaultServerURL = "http://157.66.100.10:4000"

    private let tokenKeychainKey = "app_input_auth_token"
    private let usernameDefaultsKey = "app_input_saved_username"
    private let expiresDefaultsKey = "app_input_saved_expires"
    private let serverUrlDefaultsKey = "app_input_server_url"

    @Published public var serverURL: String = defaultServerURL {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: serverUrlDefaultsKey)
        }
    }

    @Published public var isAuthenticated: Bool = false
    @Published public var currentUsername: String? = nil
    @Published public var userExpiresAt: String? = nil
    @Published public var authToken: String? = nil
    @Published public var errorMessage: String? = nil
    @Published public var isLoading: Bool = false

    private init() {
        self.serverURL = AppAuthManager.defaultServerURL
        UserDefaults.standard.set(AppAuthManager.defaultServerURL, forKey: serverUrlDefaultsKey)

        // Tự động khôi phục phiên đăng nhập đã lưu (Ghi nhớ đăng nhập)
        restoreSavedSession()

        // Mỗi lần mở lại app từ nền -> kiểm tra lại online với server
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.validateSessionOnline()
        }
    }

    /// Khôi phục phiên đăng nhập từ iOS Keychain
    public func restoreSavedSession() {
        guard let savedToken = KeychainManager.shared.load(key: tokenKeychainKey), !savedToken.isEmpty else {
            self.isAuthenticated = false
            return
        }

        let savedUser = UserDefaults.standard.string(forKey: usernameDefaultsKey)
        let savedExpires = UserDefaults.standard.string(forKey: expiresDefaultsKey)

        // Kiểm tra xem hạn dùng đã quá hạn chưa nếu có thông tin
        if let expStr = savedExpires, let expDate = ISO8601DateFormatter().date(from: expStr) {
            if expDate < Date() {
                // Đã hết hạn -> xóa phiên và yêu cầu login lại
                logout()
                self.errorMessage = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại!"
                return
            }
        }

        self.authToken = savedToken
        self.currentUsername = savedUser
        self.userExpiresAt = savedExpires
        self.isAuthenticated = true

        validateSessionOnline()
    }

    /// Kiểm tra online với server (GET /api/auth/me) giống app Live.
    /// - Server trả 401/403/404 (tài khoản bị xóa, token vô hiệu, hết hạn) -> đăng xuất + xóa bản quyền.
    /// - Lỗi mạng (không có kết nối) -> giữ nguyên phiên để dùng offline.
    public func validateSessionOnline() {
        guard let token = self.authToken, !token.isEmpty else { return }
        let clean = AppAuthManager.normalizeURL(serverURL)
        guard let url = URL(string: "\(clean)/api/auth/me") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, error == nil, let http = response as? HTTPURLResponse else { return }
            DispatchQueue.main.async {
                if [401, 403, 404].contains(http.statusCode) {
                    self.logout()
                    self.errorMessage = "Tài khoản không còn hiệu lực. Vui lòng đăng nhập lại!"
                    return
                }
                guard http.statusCode == 200, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let user = json["user"] as? [String: Any] else { return }
                if let exp = user["expiresAt"] as? String {
                    self.userExpiresAt = exp
                    UserDefaults.standard.set(exp, forKey: self.expiresDefaultsKey)
                }
                if let uname = user["username"] as? String, uname != self.currentUsername {
                    // Token thuộc tài khoản khác chủ bản quyền -> xóa bản quyền cũ
                    LicenseService.shared.clearLicenseIfOwnerMismatch(currentUser: uname)
                    self.currentUsername = uname
                    UserDefaults.standard.set(uname, forKey: self.usernameDefaultsKey)
                }
            }
        }.resume()
    }

    public static func normalizeURL(_ raw: String) -> String {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return clean }
        if !clean.hasPrefix("http://") && !clean.hasPrefix("https://") {
            clean = "http://\(clean)"
        }
        while clean.hasSuffix("/") {
            clean.removeLast()
        }
        return clean
    }

    /// Đăng nhập tài khoản, gửi định danh phần cứng máy lên Server (Tối đa 2 máy Nhập)
    public func login(username: String, password: String, completion: @escaping (Bool) -> Void) {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanUsername.isEmpty, !cleanPassword.isEmpty else {
            self.errorMessage = "Vui lòng nhập đầy đủ Tài khoản và Mật khẩu."
            completion(false)
            return
        }

        let cleanServer = AppAuthManager.normalizeURL(self.serverURL)
        guard let url = URL(string: "\(cleanServer)/api/auth/login") else {
            self.errorMessage = "Địa chỉ Server URL không hợp lệ."
            completion(false)
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        let deviceUuid = DeviceIdentityService.shared.getOrCreateHardwareUUID()
        let deviceFingerprint = DeviceIdentityService.shared.getDeviceFingerprint()
        let deviceModel = DeviceIdentityService.shared.getDeviceModelName()

        let payload: [String: Any] = [
            "username": cleanUsername,
            "password": cleanPassword,
            "platform": "mobile",
            "appType": "APP_INPUT",
            "deviceUuid": deviceUuid,
            "deviceFingerprint": deviceFingerprint,
            "deviceModel": deviceModel
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Không thể kết nối máy chủ: \(error.localizedDescription)"
                    completion(false)
                    return
                }

                guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.errorMessage = "Dữ liệu máy chủ trả về không hợp lệ."
                    completion(false)
                    return
                }

                if let errStr = json["error"] as? String {
                    self.errorMessage = errStr
                    completion(false)
                    return
                }

                guard let token = json["token"] as? String, let user = json["user"] as? [String: Any] else {
                    self.errorMessage = "Đăng nhập thất bại. Thiếu token xác thực."
                    completion(false)
                    return
                }

                let username = user["username"] as? String ?? cleanUsername
                let expiresAt = user["expiresAt"] as? String

                LicenseService.shared.clearLicenseIfOwnerMismatch(currentUser: username)
                self.authToken = token
                self.currentUsername = username
                self.userExpiresAt = expiresAt
                self.isAuthenticated = true
                self.errorMessage = nil

                // Ghi nhớ phiên đăng nhập an toàn vào iOS Keychain & UserDefaults
                KeychainManager.shared.save(key: self.tokenKeychainKey, value: token)
                UserDefaults.standard.set(username, forKey: self.usernameDefaultsKey)
                if let exp = expiresAt {
                    UserDefaults.standard.set(exp, forKey: self.expiresDefaultsKey)
                }

                // Nếu tài khoản đã được kích hoạt license trước đó và server trả về token, lưu luôn
                if let licToken = json["licenseToken"] as? String, !licToken.isEmpty {
                    KeychainManager.shared.save(key: "voice_offline_license_token", value: licToken)
                    LicenseService.shared.checkLicenseOffline()
                }

                completion(true)
            }
        }.resume()
    }

    /// Đăng xuất và xóa phiên đăng nhập đã lưu
    public func logout() {
        self.authToken = nil
        self.currentUsername = nil
        self.userExpiresAt = nil
        self.isAuthenticated = false
        self.errorMessage = nil

        KeychainManager.shared.delete(key: tokenKeychainKey)
        UserDefaults.standard.removeObject(forKey: usernameDefaultsKey)
        UserDefaults.standard.removeObject(forKey: expiresDefaultsKey)
        LicenseService.shared.clearLicense()
    }
}
