import Foundation

/// KIS 원시 응답을 도메인 모델(`Holding`)로 변환하는 순수 함수 모음.
/// 수치는 모두 문자열로 내려오므로 Double 변환을 거친다.
public enum KISMapper {

    /// 국내 잔고 → 보유 종목. (market: `.krStock`, currency: `.krw`)
    /// 수량 0 이하는 제외한다.
    public static func makeDomesticHoldings(
        _ response: KISDomesticBalanceResponse
    ) -> [Holding] {
        (response.output1 ?? [])
            .compactMap { item -> Holding? in
                let qty = parse(item.quantity)
                guard qty > 0 else { return nil }
                return Holding(
                    symbol: item.symbol,
                    name: item.name,
                    market: .krStock,
                    quantity: qty,
                    averageCost: parse(item.averagePrice),
                    currentPrice: parse(item.currentPrice),
                    currency: .krw
                )
            }
    }

    /// 해외 잔고 → 보유 종목. (market: `.usStock`, currency: `.usd`)
    /// 수량 0 이하는 제외한다.
    public static func makeOverseasHoldings(
        _ response: KISOverseasBalanceResponse
    ) -> [Holding] {
        (response.output1 ?? [])
            .compactMap { item -> Holding? in
                let qty = parse(item.quantity)
                guard qty > 0 else { return nil }
                return Holding(
                    symbol: item.symbol,
                    name: item.name,
                    market: .usStock,
                    quantity: qty,
                    averageCost: parse(item.averagePrice),
                    currentPrice: parse(item.currentPrice),
                    currency: .usd
                )
            }
    }

    /// 콤마/공백을 제거하고 Double 로 파싱한다. 실패 시 0.
    private static func parse(_ string: String) -> Double {
        let cleaned = string
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }
}
