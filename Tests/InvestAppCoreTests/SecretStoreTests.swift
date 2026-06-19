import XCTest
@testable import InvestAppCore

/// `InMemorySecretStore` 로 `SecretStore` 계약을 검증한다.
/// (실제 `KeychainManager` 는 Keychain 호스트가 필요하므로 통합 테스트에서 별도 검증)
final class SecretStoreTests: XCTestCase {

    func test_saveThenLoad_returnsValue() throws {
        let store = InMemorySecretStore()
        try store.save("access-123", for: .upbitAccessKey)
        XCTAssertEqual(try store.load(for: .upbitAccessKey), "access-123")
    }

    func test_load_missing_throwsNotFound() {
        let store = InMemorySecretStore()
        XCTAssertThrowsError(try store.load(for: .upbitSecretKey)) { error in
            XCTAssertEqual(error as? KeychainError, .notFound)
        }
    }

    func test_save_overwritesExisting() throws {
        let store = InMemorySecretStore()
        try store.save("old", for: .upbitSecretKey)
        try store.save("new", for: .upbitSecretKey)
        XCTAssertEqual(try store.load(for: .upbitSecretKey), "new")
    }

    func test_delete_removesValue() throws {
        let store = InMemorySecretStore(seed: [.upbitAccessKey: "x"])
        XCTAssertTrue(store.contains(.upbitAccessKey))
        try store.delete(for: .upbitAccessKey)
        XCTAssertFalse(store.contains(.upbitAccessKey))
    }

    func test_keychainKeys_areUnique() {
        let raw = KeychainKey.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raw).count, raw.count, "Keychain 키 식별자는 중복되면 안 된다")
    }
}
