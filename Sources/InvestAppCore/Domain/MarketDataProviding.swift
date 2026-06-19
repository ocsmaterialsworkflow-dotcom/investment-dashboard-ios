import Foundation

/// 시세/배당 시장 데이터 공급자 추상화.
///
/// 구현체(예: `FinnhubClient`) 를 교체하거나 테스트 더블로 대체할 수 있다.
public protocol MarketDataProviding: Sendable {

    /// 심볼의 현재가(원 통화, 보통 USD).
    func quote(symbol: String) async throws -> Double

    /// 기간 내 배당 일정.
    /// - Parameters:
    ///   - symbol: 종목 심볼 (예: "AAPL").
    ///   - from: 조회 시작일.
    ///   - to: 조회 종료일.
    func dividends(symbol: String, from: Date, to: Date) async throws -> [DividendSchedule]
}
