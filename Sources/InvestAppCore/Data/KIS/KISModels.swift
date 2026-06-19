import Foundation

// MARK: - 토큰

/// KIS `POST /oauth2/tokenP` 응답.
///
/// 토큰 형태가 표준 OAuth2 와 약간 다르다(만료 시각 문자열 별도 제공).
/// ```json
/// { "access_token": "...", "token_type": "Bearer",
///   "expires_in": 86400, "access_token_token_expired": "2026-06-20 12:00:00" }
/// ```
public struct KISTokenResponse: Codable, Sendable, Equatable {
    public let accessToken: String
    public let tokenType: String?
    public let expiresIn: Double?
    public let accessTokenExpired: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case accessTokenExpired = "access_token_token_expired"
    }
}

// MARK: - 국내 잔고

/// `GET /uapi/domestic-stock/v1/trading/inquire-balance` 응답.
/// 보유 종목은 `output1` 배열, 계좌 요약은 `output2` 에 담긴다.
///
/// ⚠️ 실제 응답 스키마는 발급 후 검증 필요.
public struct KISDomesticBalanceResponse: Codable, Sendable, Equatable {
    public let output1: [KISDomesticHolding]?
    /// `rt_cd == "0"` 이면 정상.
    public let rtCd: String?
    public let msg1: String?

    enum CodingKeys: String, CodingKey {
        case output1
        case rtCd = "rt_cd"
        case msg1
    }
}

/// KIS 국내 보유 종목 1건. 모든 수치는 문자열로 내려온다.
///
/// ⚠️ 실제 응답 스키마는 발급 후 검증 필요.
public struct KISDomesticHolding: Codable, Sendable, Equatable {
    public let symbol: String          // 종목코드 "005930" (pdno)
    public let name: String            // 종목명 (prdt_name)
    public let quantity: String        // 보유수량 (hldg_qty)
    public let averagePrice: String    // 매입평균가 (pchs_avg_pric)
    public let currentPrice: String    // 현재가 (prpr)

    enum CodingKeys: String, CodingKey {
        case symbol = "pdno"
        case name = "prdt_name"
        case quantity = "hldg_qty"
        case averagePrice = "pchs_avg_pric"
        case currentPrice = "prpr"
    }
}

// MARK: - 해외 잔고

/// `GET /uapi/overseas-stock/v1/trading/inquire-balance` 응답.
///
/// ⚠️ 실제 응답 스키마는 발급 후 검증 필요.
public struct KISOverseasBalanceResponse: Codable, Sendable, Equatable {
    public let output1: [KISOverseasHolding]?
    public let rtCd: String?
    public let msg1: String?

    enum CodingKeys: String, CodingKey {
        case output1
        case rtCd = "rt_cd"
        case msg1
    }
}

/// KIS 해외 보유 종목 1건. 통화는 응답의 `ovrs_cblc_div` / `tr_crcy_cd` 기준이나
/// 미국 주식은 USD 로 가정한다.
///
/// ⚠️ 실제 응답 스키마는 발급 후 검증 필요.
public struct KISOverseasHolding: Codable, Sendable, Equatable {
    public let symbol: String          // 해외 종목코드 "AAPL" (ovrs_pdno)
    public let name: String            // 종목명 (ovrs_item_name)
    public let quantity: String        // 보유수량 (ovrs_cblc_qty)
    public let averagePrice: String    // 매입평균가 (pchs_avg_pric)
    public let currentPrice: String    // 현재가 (now_pric2)
    public let currencyCode: String?   // 거래통화 (tr_crcy_cd)

    enum CodingKeys: String, CodingKey {
        case symbol = "ovrs_pdno"
        case name = "ovrs_item_name"
        case quantity = "ovrs_cblc_qty"
        case averagePrice = "pchs_avg_pric"
        case currentPrice = "now_pric2"
        case currencyCode = "tr_crcy_cd"
    }
}
