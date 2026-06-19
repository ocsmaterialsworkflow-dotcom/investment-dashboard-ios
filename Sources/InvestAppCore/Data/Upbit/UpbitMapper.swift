import Foundation

/// 업비트 API 원시 응답을 도메인 모델(`Holding`)로 변환하는 순수 함수 모음.
/// 네트워크와 분리되어 단독 테스트가 가능하다.
public enum UpbitMapper {

    /// 업비트 계좌 + 현재가를 합쳐 보유 종목 목록을 만든다.
    ///
    /// - 원화(KRW) 잔고는 현금으로 보고 별도 처리 대상이므로 종목 변환에서 제외한다.
    /// - 현재가를 찾지 못한 종목은 평단가를 현재가로 사용한다(부분 실패 허용).
    /// - Parameters:
    ///   - accounts: `/v1/accounts` 결과
    ///   - tickers: `/v1/ticker` 결과 (market → ticker)
    /// - Returns: 코인 보유 종목 목록 (수량 0 이하 제외)
    public static func makeHoldings(
        accounts: [UpbitAccount],
        tickers: [UpbitTicker]
    ) -> [Holding] {
        let priceByMarket = Dictionary(
            tickers.map { ($0.market, $0.tradePrice) },
            uniquingKeysWith: { first, _ in first }
        )

        return accounts
            .filter { !$0.isFiat && $0.totalQuantity > 0 }
            .map { account in
                let avg = Double(account.avgBuyPrice) ?? 0
                let price = priceByMarket[account.krwMarketCode] ?? avg
                return Holding(
                    symbol: account.currency,
                    name: account.currency,
                    market: .crypto,
                    quantity: account.totalQuantity,
                    averageCost: avg,
                    currentPrice: price,
                    currency: .krw
                )
            }
    }

    /// 원화(KRW) 현금 잔고 합계.
    public static func krwCashBalance(accounts: [UpbitAccount]) -> Double {
        accounts.filter { $0.isFiat }.reduce(0) { $0 + $1.totalQuantity }
    }
}
