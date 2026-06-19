import Foundation
import Observation

/// USD/KRW 환율을 관리하고 UI 레이어에 제공하는 Observable 매니저.
///
/// - `refresh()` 를 호출하면 주입된 provider 에서 최신 환율을 가져온다.
/// - 에러 발생 시 마지막으로 성공한 값을 유지한다 (기본값 1300.0).
@MainActor
@Observable
public final class ExchangeRateManager {

    /// 현재 USD→KRW 환율. 기본값은 1300.0.
    public var usdToKrw: Double = 1300.0

    /// 마지막으로 환율이 성공적으로 갱신된 시각.
    public var lastUpdated: Date?

    /// 환율 로딩 중 여부.
    public var isLoading: Bool = false

    private let provider: ExchangeRateProviding

    public init(provider: ExchangeRateProviding) {
        self.provider = provider
    }

    // MARK: - Public Methods

    /// 최신 환율을 비동기로 가져와 `usdToKrw` 와 `lastUpdated` 를 갱신한다.
    ///
    /// 에러가 발생하면 로그 없이 무시하고 마지막 유효 값을 유지한다.
    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rate = try await provider.latestUSDKRW()
            usdToKrw = rate
            lastUpdated = Date()
        } catch {
            // 에러는 삼킨다 — 마지막 성공 값 유지
        }
    }

    /// USD 금액을 현재 환율 기준 KRW 로 환산한다.
    /// - Parameter usd: USD 금액
    /// - Returns: KRW 환산 금액
    public func convert(usd: Double) -> Double {
        usd * usdToKrw
    }
}
