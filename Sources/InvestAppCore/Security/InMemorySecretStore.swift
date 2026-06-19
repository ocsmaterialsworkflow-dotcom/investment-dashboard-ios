import Foundation

/// 테스트/프리뷰용 인메모리 `SecretStore`.
///
/// 실제 Keychain 은 호스트 환경(시뮬레이터/기기)이 필요하므로,
/// 순수 로직 단위 테스트에서는 이 목 구현으로 대체한다.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var storage: [KeychainKey: String] = [:]
    private let lock = NSLock()

    public init(seed: [KeychainKey: String] = [:]) {
        self.storage = seed
    }

    public func save(_ value: String, for key: KeychainKey) throws {
        lock.lock(); defer { lock.unlock() }
        storage[key] = value
    }

    public func load(for key: KeychainKey) throws -> String {
        lock.lock(); defer { lock.unlock() }
        guard let value = storage[key] else { throw KeychainError.notFound }
        return value
    }

    public func delete(for key: KeychainKey) throws {
        lock.lock(); defer { lock.unlock() }
        storage[key] = nil
    }

    public func contains(_ key: KeychainKey) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return storage[key] != nil
    }
}
