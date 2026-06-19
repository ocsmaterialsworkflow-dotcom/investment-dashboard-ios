import Foundation

/// 문자열 또는 숫자로 내려올 수 있는 수치 필드를 모두 수용하는 디코딩 래퍼.
///
/// 증권사 잔고 API 는 같은 필드를 응답마다 `"123.45"`(문자열) 또는 `123.45`(숫자)로
/// 내려보내는 경우가 잦다. 이 타입으로 감싸 두 경우 모두 안전하게 Double 로 파싱한다.
public struct FlexibleDouble: Codable, Sendable, Equatable {
    public let value: Double

    public init(_ value: Double) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            value = d
        } else if let s = try? container.decode(String.self) {
            // 콤마 천단위 구분자 제거 후 파싱.
            let cleaned = s.replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespaces)
            value = Double(cleaned) ?? 0
        } else if let i = try? container.decode(Int.self) {
            value = Double(i)
        } else {
            value = 0
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - 국내(원화) 잔고

/// 토스증권 국내 주식 잔고 응답.
///
/// ⚠️ 실제 응답 스키마는 발급 후 검증 필요 — 필드명/중첩 구조는 추정값이다.
public struct TossDomesticBalanceResponse: Codable, Sendable, Equatable {
    public let holdings: [TossDomesticHolding]

    enum CodingKeys: String, CodingKey {
        case holdings
    }
}

/// 토스증권 국내 보유 종목 1건.
///
/// ⚠️ 실제 응답 스키마는 발급 후 검증 필요.
public struct TossDomesticHolding: Codable, Sendable, Equatable {
    public let symbol: String          // 종목코드 "005930"
    public let name: String            // 종목명 "삼성전자"
    public let quantity: FlexibleDouble
    public let averagePrice: FlexibleDouble   // 평균 매입가 (KRW)
    public let currentPrice: FlexibleDouble   // 현재가 (KRW)

    enum CodingKeys: String, CodingKey {
        case symbol = "stock_code"
        case name = "stock_name"
        case quantity = "balance_qty"
        case averagePrice = "avg_buy_price"
        case currentPrice = "current_price"
    }
}

// MARK: - 해외(미국) 잔고

/// 토스증권 해외 주식 잔고 응답.
///
/// ⚠️ 실제 응답 스키마는 발급 후 검증 필요.
public struct TossOverseasBalanceResponse: Codable, Sendable, Equatable {
    public let holdings: [TossOverseasHolding]

    enum CodingKeys: String, CodingKey {
        case holdings
    }
}

/// 토스증권 해외 보유 종목 1건. 통화는 USD 기준으로 가정한다.
///
/// ⚠️ 실제 응답 스키마는 발급 후 검증 필요.
public struct TossOverseasHolding: Codable, Sendable, Equatable {
    public let symbol: String          // "AAPL"
    public let name: String            // "Apple Inc."
    public let quantity: FlexibleDouble
    public let averagePrice: FlexibleDouble   // 평균 매입가 (USD)
    public let currentPrice: FlexibleDouble   // 현재가 (USD)
    public let currencyCode: String?   // "USD"

    enum CodingKeys: String, CodingKey {
        case symbol = "ticker"
        case name = "stock_name"
        case quantity = "balance_qty"
        case averagePrice = "avg_buy_price"
        case currentPrice = "current_price"
        case currencyCode = "currency"
    }
}
