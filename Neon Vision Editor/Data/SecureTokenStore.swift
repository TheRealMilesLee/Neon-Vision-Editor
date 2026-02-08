import Foundation
import Security

enum APITokenKey: String, CaseIterable {
    case grok
    case openAI
    case gemini
    case anthropic

    var account: String {
        switch self {
        case .grok: return "GrokAPIToken"
        case .openAI: return "OpenAIAPIToken"
        case .gemini: return "GeminiAPIToken"
        case .anthropic: return "AnthropicAPIToken"
        }
    }
}

enum SecureTokenStore {
    private static let service = "h3p.Neon-Vision-Editor.tokens"

    static func token(for key: APITokenKey) -> String {
        guard let data = readData(for: key),
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    static func setToken(_ value: String, for key: APITokenKey) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            deleteToken(for: key)
            return
        }
        guard let data = trimmed.data(using: .utf8) else { return }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.account
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func migrateLegacyUserDefaultsTokens() {
        for key in APITokenKey.allCases {
            let defaultsKey = key.account
            let defaultsValue = UserDefaults.standard.string(forKey: defaultsKey) ?? ""
            let hasKeychainValue = !token(for: key).isEmpty
            if !hasKeychainValue && !defaultsValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                setToken(defaultsValue, for: key)
            }
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    private static func readData(for key: APITokenKey) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func deleteToken(for key: APITokenKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.account
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}
