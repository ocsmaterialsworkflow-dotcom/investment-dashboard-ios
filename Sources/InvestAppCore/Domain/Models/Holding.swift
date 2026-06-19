import Foundation

public enum Broker: String, Codable, Sendable, CaseIterable {
    case upbit
    case tossSecurities
    case kis            // 한국투자증권 (NH 대체 후보)
    case nhInvestment   // NH투자증권 — iOS 직접연동 불가, 브릿지 백엔드 전제(placeholder)
}

public enum Market: String, Codable, Sendable {
    case crypto
    case usStock
    case krStock
}

public enum Currency: String, Codable, Sendable {
    case krw
    case usd
}

/// 보유 종목 1건.
///
/// 내부 계산은 원 통화(`currency`)로 유지하고, **화면에 표시되기 직전에만** KRW 로 변환한다.
/// (환율 변동에 따른 누적 오차 방지)
public struct Holding: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let symbol: String        // "BTC", "AAPL", "005930"
    public let name: String
    public let market: Market
    public var quantity: Double
    public var averageCost: Double   // 평균 매수가 (원 통화 기준)
    public var currentPrice: Double  // 현재가 (원 통화 기준)
    public var currency: Currency

    public init(
        id: UUID = UUID(),
        symbol: String,
        name: String,
        market: Market,
        quantity: Double,
        averageCost: Double,
        currentPrice: Double,
        currency: Currency
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.market = market
        self.quantity = quantity
        self.averageCost = averageCost
        self.currentPrice = currentPrice
        self.currency = currency
    }

    /// 원 통화 기준 평가금액.
    public var evaluatedValue: Double { quantity * currentPrice }

    /// 원 통화 기준 매수원금.
    public var costBasis: Double { quantity * averageCost }

    /// 원 통화 기준 평가손익.
    public var profitLoss: Double { evaluatedValue - costBasis }

    /// 수익률(%). 원금이 0이면 0.
    public var profitLossRate: Double {
        guard costBasis != 0 else { return 0 }
        return profitLoss / costBasis * 100
    }

    /// 지정 환율로 변환한 KRW 평가금액.
    /// - Parameter usdToKrw: USD→KRW 환율. `currency == .krw` 면 환율 무시.
    public func evaluatedValueKRW(usdToKrw: Double) -> Double {
        switch currency {
        case .krw: return evaluatedValue
        case .usd: return evaluatedValue * usdToKrw
        }
    }
}
