import Foundation

/// `GET /v1/accounts` 응답 1건.
/// 모든 수치는 문자열로 내려오므로 Double 변환이 필요하다.
public struct UpbitAccount: Codable, Sendable, Equatable {
    public let currency: String          // "BTC", "KRW", "USDT"
    public let balance: String           // 주문 가능 수량
    public let locked: String            // 주문 중 묶인 수량
    public let avgBuyPrice: String       // 매수 평균가
    public let avgBuyPriceModified: Bool
    public let unitCurrency: String      // 평단 기준 통화 "KRW"

    enum CodingKeys: String, CodingKey {
        case currency, balance, locked
        case avgBuyPrice = "avg_buy_price"
        case avgBuyPriceModified = "avg_buy_price_modified"
        case unitCurrency = "unit_currency"
    }

    /// 보유 총수량(가용 + 잠김).
    public var totalQuantity: Double {
        (Double(balance) ?? 0) + (Double(locked) ?? 0)
    }

    /// 업비트 마켓 코드. KRW 마켓 기준. (예: BTC → "KRW-BTC")
    public var krwMarketCode: String { "KRW-\(currency)" }

    public var isFiat: Bool { currency == "KRW" }
}

/// `GET /v1/ticker?markets=...` 응답 1건. (인증 불필요)
public struct UpbitTicker: Codable, Sendable, Equatable {
    public let market: String            // "KRW-BTC"
    public let tradePrice: Double        // 현재가

    enum CodingKeys: String, CodingKey {
        case market
        case tradePrice = "trade_price"
    }
}
