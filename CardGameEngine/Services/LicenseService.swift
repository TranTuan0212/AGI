import Foundation
import Combine
import CommonCrypto

public enum LicenseStatus {
    case unactivated
    case active(expiresAt: Date, isLifetime: Bool)
    case expired(expiredAt: Date)
}

/// LicenseService quản lý bản quyền Giọng nói:
/// - Kích hoạt lần đầu / Gia hạn: Cần mạng kết nối Server
/// - Khi sử dụng Giọng nói: Hoàn toàn 100% OFFLINE (không gửi request mạng)
public class LicenseService: ObservableObject {
    public static let shared = LicenseService()

    private let licenseTokenKey = "voice_license_token"
    private let licenseDataKey = "voice_license_data_json"
    private let lastClockTimestampKey = "voice_license_last_clock_timestamp"
    private let licenseSecretKey = "VOICE_LICENSE_MASTER_HMAC_KEY_SECURE_2026"

    public static let defaultServerUrl = "http://157.66.100.10:4000"

    @Published public var isVoiceUnlocked: Bool = false
    @Published public var licenseStatus: LicenseStatus = .unactivated
    @Published public var registeredAtDate: Date? = nil
    @Published public var expiresAtDate: Date? = nil
    @Published public var isLifetime: Bool = false
    @Published public var remainingTimeText: String = "Chưa kích hoạt"
    @Published public var statusMessage: String = ""

    private var timer: Timer?

    private init() {
        checkLicenseOffline()
        startPeriodicCheck()
    }

    deinit {
        timer?.invalidate()
    }

    private func startPeriodicCheck() {
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkLicenseOffline()
        }
    }

    /// Kiểm tra bản quyền hoàn toàn Offline từ iOS Keychain (không cần kết nối mạng)
    public func checkLicenseOffline() {
        guard let token = KeychainManager.shared.load(key: licenseTokenKey), !token.isEmpty else {
            DispatchQueue.main.async {
                self.isVoiceUnlocked = false
                self.licenseStatus = .unactivated
                self.remainingTimeText = "Chưa kích hoạt"
            }
            return
        }

        let myFingerprint = DeviceIdentityService.shared.getDeviceFingerprint()
        let verifyResult = verifyOfflineToken(token: token, expectedFingerprint: myFingerprint)

        DispatchQueue.main.async {
            if verifyResult.valid {
                self.isVoiceUnlocked = true
                self.registeredAtDate = verifyResult.registeredAt
                self.expiresAtDate = verifyResult.expiresAt
                self.isLifetime = verifyResult.isLifetime

                if verifyResult.isLifetime {
                    self.licenseStatus = .active(expiresAt: verifyResult.expiresAt ?? Date(), isLifetime: true)
                    self.remainingTimeText = "Vĩnh viễn (Lifetime)"
                } else if let exp = verifyResult.expiresAt {
                    self.licenseStatus = .active(expiresAt: exp, isLifetime: false)
                    self.remainingTimeText = self.formatRemainingTime(from: Date(), to: exp)
                }
            } else {
                self.isVoiceUnlocked = false
                if let exp = verifyResult.expiresAt {
                    self.licenseStatus = .expired(expiredAt: exp)
                    self.remainingTimeText = "Đã hết hạn vào: \(self.formatDate(exp))"
                } else {
                    self.licenseStatus = .unactivated
                    self.remainingTimeText = verifyResult.error ?? "Chưa kích hoạt"
                }
            }
        }
    }

    /// Kích hoạt bản quyền qua Server (CẦN MẠNG LẦN ĐẦU)
    public func activateWithKey(
        serverUrl: String = defaultServerUrl,
        licenseKey: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let cleanKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let myFingerprint = DeviceIdentityService.shared.getDeviceFingerprint()
        let myModel = DeviceIdentityService.shared.getDeviceModelName()

        guard let url = URL(string: "\(cleanUrl)/api/license/activate") else {
            completion(.failure(NSError(domain: "LicenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Server URL không hợp lệ."])))
            return
        }

        let payload: [String: Any] = [
            "licenseKey": cleanKey,
            "deviceFingerprint": myFingerprint,
            "deviceModel": myModel
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LicenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không thể kết nối Server: \(error.localizedDescription)"])))
                }
                return
            }

            guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LicenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu phản hồi từ server không hợp lệ."])))
                }
                return
            }

            if let errStr = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LicenseService", code: 403, userInfo: [NSLocalizedDescriptionKey: errStr])))
                }
                return
            }

            guard let token = json["licenseToken"] as? String else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LicenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server không trả về License Token hợp lệ."])))
                }
                return
            }

            // Lưu trữ an toàn Token vào iOS Keychain
            KeychainManager.shared.save(key: self.licenseTokenKey, value: token)
            if let jsonString = String(data: data, encoding: .utf8) {
                KeychainManager.shared.save(key: self.licenseDataKey, value: jsonString)
            }

            // Cập nhật trạng thái
            self.checkLicenseOffline()

            DispatchQueue.main.async {
                let msg = json["message"] as? String ?? "Kích hoạt bản quyền thành công!"
                completion(.success(msg))
            }
        }.resume()
    }

    /// Gia hạn bản quyền qua Server (CẦN MẠNG KHI GIA HẠN)
    public func renewWithKey(
        serverUrl: String = defaultServerUrl,
        renewKey: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let cleanKey = renewKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let myFingerprint = DeviceIdentityService.shared.getDeviceFingerprint()

        guard let url = URL(string: "\(cleanUrl)/api/license/renew") else {
            completion(.failure(NSError(domain: "LicenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Server URL không hợp lệ."])))
            return
        }

        let payload: [String: Any] = [
            "renewKey": cleanKey,
            "deviceFingerprint": myFingerprint
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LicenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không thể kết nối Server: \(error.localizedDescription)"])))
                }
                return
            }

            guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LicenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu phản hồi từ server không hợp lệ."])))
                }
                return
            }

            if let errStr = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LicenseService", code: 403, userInfo: [NSLocalizedDescriptionKey: errStr])))
                }
                return
            }

            guard let newToken = json["licenseToken"] as? String else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LicenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server không trả về Token gia hạn mới."])))
                }
                return
            }

            // Cập nhật Token mới vào Keychain
            KeychainManager.shared.save(key: self.licenseTokenKey, value: newToken)
            if let jsonString = String(data: data, encoding: .utf8) {
                KeychainManager.shared.save(key: self.licenseDataKey, value: jsonString)
            }

            self.checkLicenseOffline()

            DispatchQueue.main.async {
                let msg = json["message"] as? String ?? "Gia hạn bản quyền thành công!"
                completion(.success(msg))
            }
        }.resume()
    }

    /// Xác thực offline token bằng chữ ký số HMAC-SHA256 cục bộ
    private func verifyOfflineToken(
        token: String,
        expectedFingerprint: String
    ) -> (valid: Bool, registeredAt: Date?, expiresAt: Date?, isLifetime: Bool, error: String?) {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 2 else {
            return (false, nil, nil, false, "Token cấu trúc không hợp lệ")
        }

        let payloadB64 = parts[0]
        let providedSig = parts[1]

        // Tính lại HMAC-SHA256 signature
        let expectedSig = computeHmacSha256Base64Url(message: payloadB64, key: licenseSecretKey)
        if providedSig != expectedSig {
            return (false, nil, nil, false, "Chữ ký Token không hợp lệ")
        }

        guard let payloadData = base64UrlDecode(payloadB64),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return (false, nil, nil, false, "Không thể đọc dữ liệu Token")
        }

        guard let tokenFp = json["fp"] as? String, tokenFp == expectedFingerprint else {
            return (false, nil, nil, false, "Token không khớp với thiết bị này")
        }

        let isLifetime = (json["life"] as? Int) == 1
        let regStr = json["reg"] as? String
        let expStr = json["exp"] as? String

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let regDate = regStr.flatMap { isoFormatter.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }
        let expDate = expStr.flatMap { isoFormatter.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }

        if !isLifetime {
            guard let expiry = expDate else {
                return (false, regDate, nil, false, "Thiếu thời hạn bản quyền")
            }

            let now = Date()

            // Kiểm tra chống tua lùi giờ hệ thống
            if let lastClockStr = KeychainManager.shared.load(key: lastClockTimestampKey),
               let lastTimestamp = Double(lastClockStr) {
                let lastDate = Date(timeIntervalSince1970: lastTimestamp)
                if now < lastDate.addingTimeInterval(-300) { // Lùi hơn 5 phút
                    return (false, regDate, expiry, false, "Phát hiện thay đổi đồng hồ hệ thống")
                }
            }
            KeychainManager.shared.save(key: lastClockTimestampKey, value: "\(now.timeIntervalSince1970)")

            if now > expiry {
                return (false, regDate, expiry, false, "Bản quyền đã hết hạn")
            }
        }

        return (true, regDate, expDate, isLifetime, nil)
    }

    private func computeHmacSha256Base64Url(message: String, key: String) -> String {
        guard let keyData = key.data(using: .utf8),
              let messageData = message.data(using: .utf8) else { return "" }

        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { keyBytes in
            messageData.withUnsafeBytes { messageBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, keyData.count, messageBytes.baseAddress, messageData.count, &hmac)
            }
        }

        let rawData = Data(hmac)
        return rawData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func base64UrlDecode(_ base64Url: String) -> Data? {
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        return Data(base64Encoded: base64)
    }

    public func formatRemainingTime(from start: Date, to end: Date) -> String {
        let diff = end.timeIntervalSince(start)
        if diff <= 0 { return "Đã hết hạn" }

        let days = Int(diff) / 86400
        let hours = (Int(diff) % 86400) / 3600
        let minutes = (Int(diff) % 3600) / 60

        if days > 0 {
            return "Còn \(days) ngày \(hours) giờ"
        } else if hours > 0 {
            return "Còn \(hours) giờ \(minutes) phút"
        } else {
            return "Còn \(minutes) phút"
        }
    }

    public func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd/MM/yyyy HH:mm"
        return df.string(from: date)
    }
}
