import Foundation

/// 1차 제공자가 실패할 경우 2차 제공자로 자동 전환하는 환율 저장소.
///
/// - primary 가 성공하면 그 값을 그대로 반환한다.
/// - primary 가 에러를 던지면 fallback 에 위임한다.
public struct ExchangeRateRepository: ExchangeRateProviding {

    private let primary: ExchangeRateProviding
    private let fallback: ExchangeRateProviding

    public init(primary: ExchangeRateProviding, fallback: ExchangeRateProviding) {
        self.primary = primary
        self.fallback = fallback
    }

    // MARK: - ExchangeRateProviding

    public func latestUSDKRW() async throws -> Double {
        do {
            return try await primary.latestUSDKRW()
        } catch {
            return try await fallback.latestUSDKRW()
        }
    }
}
