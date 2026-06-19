import Foundation

/// 토스증권 원시 응답을 도메인 모델(`Holding`)로 변환하는 순수 함수 모음.
/// 네트워크와 분리되어 단독 테스트가 가능하다.
public enum TossMapper {

    /// 국내 잔고 → 보유 종목. (market: `.krStock`, currency: `.krw`)
    /// 수량 0 이하는 제외한다.
    public static func makeDomesticHoldings(
        _ response: TossDomesticBalanceResponse
    ) -> [Holding] {
        response.holdings
            .filter { $0.quantity.value > 0 }
            .map { item in
                Holding(
                    symbol: item.symbol,
                    name: item.name,
                    market: .krStock,
                    quantity: item.quantity.value,
                    averageCost: item.averagePrice.value,
                    currentPrice: item.currentPrice.value,
                    currency: .krw
                )
            }
    }

    /// 해외 잔고 → 보유 종목. (market: `.usStock`, currency: `.usd`)
    /// 수량 0 이하는 제외한다.
    public static func makeOverseasHoldings(
        _ response: TossOverseasBalanceResponse
    ) -> [Holding] {
        response.holdings
            .filter { $0.quantity.value > 0 }
            .map { item in
                Holding(
                    symbol: item.symbol,
                    name: item.name,
                    market: .usStock,
                    quantity: item.quantity.value,
                    averageCost: item.averagePrice.value,
                    currentPrice: item.currentPrice.value,
                    currency: .usd
                )
            }
    }
}
