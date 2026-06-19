import Foundation

/// USD/KRW 환율을 제공하는 서비스의 추상화.
///
/// 다양한 데이터 소스(한국은행 ECOS, 무료 fallback 등)를 동일한 인터페이스로 감쌀 수 있다.
public protocol ExchangeRateProviding: Sendable {
    /// 최신 USD/KRW 매매기준율(원/달러)을 반환한다.
    /// - Returns: 1 USD 에 해당하는 KRW 금액 (예: 1380.5)
    func latestUSDKRW() async throws -> Double
}
