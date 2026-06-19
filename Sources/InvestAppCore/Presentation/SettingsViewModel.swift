import Foundation
import Observation

// MARK: - Broker Credential Info

/// 증권사별 필요 Keychain 키 묶음.
public struct BrokerCredential: Identifiable, Sendable {
    public let id: Broker
    /// 증권사 표시 이름.
    public let brokerName: String
    /// 필요한 Keychain 키 목록 (순서 중요 — 폼 순서와 일치).
    public let keys: [KeychainKey]
    /// 각 키의 라벨 (keys 와 동일 인덱스).
    public let keyLabels: [String]
    /// 지원 여부. false 면 UI 에서 비활성 안내.
    public let isSupported: Bool
    /// 미지원 사유 메모.
    public let unsupportedNote: String?

    public init(
        id: Broker,
        brokerName: String,
        keys: [KeychainKey],
        keyLabels: [String],
        isSupported: Bool = true,
        unsupportedNote: String? = nil
    ) {
        self.id = id
        self.brokerName = brokerName
        self.keys = keys
        self.keyLabels = keyLabels
        self.isSupported = isSupported
        self.unsupportedNote = unsupportedNote
    }
}

// MARK: - SettingsViewModel

/// 설정 탭 ViewModel.
///
/// - 각 증권사 API 키를 `SecretStore` 에 저장/로드/삭제한다.
/// - 화면에서는 저장된 키를 마스킹해 보여준다.
/// - NH(NH투자증권)는 현재 미지원 — 브릿지 API 필요.
/// - ViewModels 은 SwiftUI 를 import 하지 않으므로 패키지 내 단위 테스트가 가능하다.
@MainActor
@Observable
public final class SettingsViewModel {

    // MARK: - Supported Brokers

    /// 지원 증권사 목록 (UI 렌더링 순서).
    public let brokerCredentials: [BrokerCredential] = [
        BrokerCredential(
            id: .upbit,
            brokerName: "업비트 (Upbit)",
            keys: [.upbitAccessKey, .upbitSecretKey],
            keyLabels: ["Access Key", "Secret Key"]
        ),
        BrokerCredential(
            id: .tossSecurities,
            brokerName: "토스증권 (Toss Securities)",
            keys: [.tossClientId, .tossClientSecret],
            keyLabels: ["Client ID", "Client Secret"]
        ),
        BrokerCredential(
            id: .kis,
            brokerName: "한국투자증권 (KIS)",
            keys: [.kisAppKey, .kisAppSecret],
            keyLabels: ["App Key", "App Secret"]
        )
    ]

    /// 외부 API 키 항목 (BOK, Finnhub).
    public let externalKeys: [(key: KeychainKey, label: String)] = [
        (.bokApiKey,     "한국은행 API 키 (BOK)"),
        (.finnhubApiKey, "Finnhub API 키")
    ]

    // MARK: - State

    /// 각 KeychainKey → 현재 입력 중인 값 (평문).
    public var inputValues: [KeychainKey: String] = [:]

    /// 저장 완료/에러 메시지.
    public var statusMessage: String?

    /// 에러 여부 (statusMessage 색상 결정용).
    public var isStatusError: Bool = false

    /// 로딩 중 여부.
    public var isLoading: Bool = false

    // MARK: - Dependencies

    private let store: SecretStore

    // MARK: - Init

    /// - Parameter store: API 키를 저장할 SecretStore (Keychain 또는 InMemory).
    public init(store: SecretStore) {
        self.store = store
    }

    // MARK: - Public Methods

    /// 저장된 모든 키를 로드해 `inputValues` 를 설정한다.
    /// 저장되지 않은 키는 빈 문자열로 초기화.
    public func loadAll() {
        let allKeys: [KeychainKey] = brokerCredentials.flatMap(\.keys)
            + externalKeys.map(\.key)
        for key in allKeys {
            inputValues[key] = (try? store.load(for: key)) ?? ""
        }
    }

    /// 단일 키를 저장한다.
    /// - Parameters:
    ///   - key: 저장할 Keychain 키.
    ///   - value: 저장할 값 (빈 문자열이면 삭제).
    public func save(key: KeychainKey, value: String) {
        guard validate(value: value, for: key) else { return }
        do {
            if value.isEmpty {
                try store.delete(for: key)
            } else {
                try store.save(value, for: key)
            }
            statusMessage = "\(key.rawValue) 저장 완료"
            isStatusError = false
        } catch {
            statusMessage = "저장 실패: \(error.localizedDescription)"
            isStatusError = true
        }
    }

    /// 단일 키를 삭제한다.
    public func delete(key: KeychainKey) {
        do {
            try store.delete(for: key)
            inputValues[key] = ""
            statusMessage = "\(key.rawValue) 삭제 완료"
            isStatusError = false
        } catch {
            statusMessage = "삭제 실패: \(error.localizedDescription)"
            isStatusError = true
        }
    }

    /// 특정 Keychain 키가 저장되어 있는지 여부.
    public func isStored(_ key: KeychainKey) -> Bool {
        store.contains(key)
    }

    /// 저장된 값을 마스킹해 반환한다 (첫 4자 + ****).
    public func maskedValue(for key: KeychainKey) -> String {
        guard let value = try? store.load(for: key), !value.isEmpty else {
            return "미설정"
        }
        let prefix = String(value.prefix(4))
        return "\(prefix)••••••••"
    }

    /// 브로커의 모든 키가 저장되어 있는지 여부.
    public func isConnected(_ broker: BrokerCredential) -> Bool {
        broker.keys.allSatisfy { store.contains($0) }
    }

    // MARK: - Private

    /// 값 유효성 검사. 유효하지 않으면 에러 메시지를 설정하고 false 반환.
    @discardableResult
    private func validate(value: String, for key: KeychainKey) -> Bool {
        // 빈 값은 삭제 의도로 허용
        if value.isEmpty { return true }
        // 최소 길이 8자
        guard value.count >= 8 else {
            statusMessage = "키는 최소 8자 이상이어야 합니다."
            isStatusError = true
            return false
        }
        return true
    }
}
