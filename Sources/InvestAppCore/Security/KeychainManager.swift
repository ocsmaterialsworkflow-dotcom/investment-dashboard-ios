import Foundation
#if canImport(Security)
import Security
#endif

/// Keychain 에 저장하는 비밀 값의 식별자.
///
/// API Access/Secret Key, OAuth 토큰 등 **민감 정보는 오직 Keychain 에만** 저장한다.
/// UserDefaults / plist / 소스코드에 저장하는 것은 금지.
public enum KeychainKey: String, CaseIterable, Sendable {
    case upbitAccessKey = "com.investapp.upbit.accessKey"
    case upbitSecretKey = "com.investapp.upbit.secretKey"
    case tossClientId   = "com.investapp.toss.clientId"
    case tossClientSecret = "com.investapp.toss.clientSecret"
    case tossAccessToken  = "com.investapp.toss.accessToken"
    case kisAppKey      = "com.investapp.kis.appKey"
    case kisAppSecret   = "com.investapp.kis.appSecret"
    case kisAccessToken = "com.investapp.kis.accessToken"
    case bokApiKey      = "com.investapp.bok.apiKey"      // 한국은행 ECOS 환율 API
    case finnhubApiKey  = "com.investapp.finnhub.apiKey"  // 미국주식 시세·배당
}

public enum KeychainError: Error, Equatable {
    case notFound
    case invalidData
    /// `SecItem*` 가 반환한 OSStatus 를 그대로 전달한다.
    case unexpectedStatus(OSStatus)
}

/// 비밀 값 저장소 추상화. ViewModel/UseCase 는 이 프로토콜에 의존해
/// 테스트 시 인메모리 목(Mock)으로 대체할 수 있다.
public protocol SecretStore: AnyObject, Sendable {
    func save(_ value: String, for key: KeychainKey) throws
    func load(for key: KeychainKey) throws -> String
    func delete(for key: KeychainKey) throws
    func contains(_ key: KeychainKey) -> Bool
}

/// iOS Keychain 기반 `SecretStore` 구현.
///
/// - 접근성: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
///   (기기 잠금 해제 상태에서만 접근, 다른 기기로 백업/이전 불가).
/// - 앱 삭제 시 Keychain 항목도 함께 제거되도록 keychain-access-group 을 별도 공유하지 않는다.
public final class KeychainManager: SecretStore, @unchecked Sendable {

    private let service: String

    /// - Parameter service: Keychain 항목을 묶는 서비스 네임스페이스. 기본값은 번들 식별자 계열.
    public init(service: String = "com.investapp.secrets") {
        self.service = service
    }

    public func save(_ value: String, for key: KeychainKey) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // 이미 존재하면 업데이트, 없으면 추가한다.
        let query = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    public func load(for key: KeychainKey) throws -> String {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return value
        case errSecItemNotFound:
            throw KeychainError.notFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func delete(for key: KeychainKey) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func contains(_ key: KeychainKey) -> Bool {
        (try? load(for: key)) != nil
    }

    private func baseQuery(for key: KeychainKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }
}
