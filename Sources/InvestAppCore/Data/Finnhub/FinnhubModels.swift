import Foundation

/// `GET /quote?symbol=` 응답.
/// `c` = current price.
public struct FinnhubQuote: Codable, Sendable, Equatable {
    public let c: Double   // current price

    enum CodingKeys: String, CodingKey {
        case c
    }
}

/// `GET /stock/dividend?symbol=&from=&to=` 응답 1건.
/// 날짜는 "yyyy-MM-dd" 문자열.
public struct FinnhubDividend: Codable, Sendable, Equatable {
    public let symbol: String
    public let date: String     // 배당락일 (exDate)
    public let payDate: String  // 지급일
    public let amount: Double    // 1주당 배당금 (USD)

    enum CodingKeys: String, CodingKey {
        case symbol
        case date
        case payDate
        case amount
    }
}
