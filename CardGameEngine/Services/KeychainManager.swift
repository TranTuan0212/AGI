import Foundation
import Security

/// KeychainManager quản lý lưu trữ dữ liệu an toàn và bất biến trên iOS Keychain.
/// Dữ liệu tồn tại vĩnh viễn trên máy, không bị mất kể cả khi người dùng xóa app và cài lại.
public class KeychainManager {
    public static let shared = KeychainManager()
    private let serviceName = "com.cardgame.app.license"

    private init() {}

    /// Lưu chuỗi String vào Keychain với cờ kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    public func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Xóa entry cũ trước khi thêm mới
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Thêm entry mới
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Đọc chuỗi String từ Keychain
    public func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data, let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }

    /// Xóa 1 key trong Keychain
    public func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
