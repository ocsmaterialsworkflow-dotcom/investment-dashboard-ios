import Foundation

/// 한국투자증권(KIS) Open API 호출 클라이언트.
///
/// 모든 거래/잔고 API 는 다음 헤더를 요구한다:
/// `authorization: Bearer <token>`, `appkey`, `appsecret`, `tr_id`, `custtype: P`.
/// 토큰은 `KISAuthClient`(actor)가 캐싱/갱신한다.
///
/// ⚠️ 실제 응답 스키마·쿼리 파라미터는 발급 후 검증 필요.
public struct KISAPIClient: Sendable {

    public static let baseURL = URL(string: "https://openapi.koreainvestment.com:9443")!

    /// 거래 ID (tr_id).
    public enum TRID {
        public static let domesticBalance = "TTTC8434R"
        public static let overseasBalance = "TTTS3012R"
    }

    private let http: HTTPClient
    private let auth: KISAuthClient
    private let appKey: String
    private let appSecret: String
    private let accountNo: String
    private let decoder: JSONDecoder

    /// - Parameters:
    ///   - accountNo: 계좌번호(8-2 형식 등). 국내/해외 잔고 조회 쿼리에 사용한다.
    public init(
        http: HTTPClient,
        auth: KISAuthClient,
        appKey: String,
        appSecret: String,
        accountNo: String
    ) {
        self.http = http
        self.auth = auth
        self.appKey = appKey
        self.appSecret = appSecret
        self.accountNo = accountNo
        self.decoder = JSONDecoder()
    }

    /// `SecretStore` 에서 자격증명을 읽어 구성하는 편의 생성자.
    /// - Throws: 자격증명이 없으면 `NetworkError.missingCredentials`.
    public init(
        http: HTTPClient,
        secrets: SecretStore,
        accountNo: String
    ) throws {
        let appKey: String
        let appSecret: String
        do {
            appKey = try secrets.load(for: .kisAppKey)
            appSecret = try secrets.load(for: .kisAppSecret)
        } catch {
            throw NetworkError.missingCredentials
        }
        self.init(
            http: http,
            auth: try KISAuthClient(http: http, secrets: secrets),
            appKey: appKey,
            appSecret: appSecret,
            accountNo: accountNo
        )
    }

    /// 국내 주식 잔고 조회.
    public func fetchDomesticBalance() async throws -> KISDomesticBalanceResponse {
        let path = "uapi/domestic-stock/v1/trading/inquire-balance"
        let query = [
            URLQueryItem(name: "CANO", value: accountPrefix),
            URLQueryItem(name: "ACNT_PRDT_CD", value: accountSuffix),
            URLQueryItem(name: "AFHR_FLPR_YN", value: "N"),
            URLQueryItem(name: "INQR_DVSN", value: "02"),
            URLQueryItem(name: "UNPR_DVSN", value: "01"),
            URLQueryItem(name: "FUND_STTL_ICLD_YN", value: "N"),
            URLQueryItem(name: "FNCG_AMT_AUTO_RDPT_YN", value: "N"),
            URLQueryItem(name: "PRCS_DVSN", value: "00"),
            URLQueryItem(name: "CTX_AREA_FK100", value: ""),
            URLQueryItem(name: "CTX_AREA_NK100", value: "")
        ]
        return try await authorizedGet(
            KISDomesticBalanceResponse.self,
            path: path,
            trID: TRID.domesticBalance,
            query: query
        )
    }

    /// 해외 주식 잔고 조회.
    public func fetchOverseasBalance() async throws -> KISOverseasBalanceResponse {
        let path = "uapi/overseas-stock/v1/trading/inquire-balance"
        let query = [
            URLQueryItem(name: "CANO", value: accountPrefix),
            URLQueryItem(name: "ACNT_PRDT_CD", value: accountSuffix),
            URLQueryItem(name: "OVRS_EXCG_CD", value: "NASD"),
            URLQueryItem(name: "TR_CRCY_CD", value: "USD"),
            URLQueryItem(name: "CTX_AREA_FK200", value: ""),
            URLQueryItem(name: "CTX_AREA_NK200", value: "")
        ]
        return try await authorizedGet(
            KISOverseasBalanceResponse.self,
            path: path,
            trID: TRID.overseasBalance,
            query: query
        )
    }

    // MARK: - Helpers

    /// 계좌번호 앞 8자리(종합계좌번호 CANO).
    private var accountPrefix: String {
        let digits = accountNo.replacingOccurrences(of: "-", with: "")
        return String(digits.prefix(8))
    }

    /// 계좌번호 뒤 2자리(상품코드 ACNT_PRDT_CD).
    private var accountSuffix: String {
        let digits = accountNo.replacingOccurrences(of: "-", with: "")
        return digits.count > 8 ? String(digits.suffix(digits.count - 8)) : "01"
    }

    private func authorizedGet<T: Decodable>(
        _ type: T.Type,
        path: String,
        trID: String,
        query: [URLQueryItem]
    ) async throws -> T {
        let token = try await auth.token()

        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query
        guard let url = components?.url else { throw NetworkError.invalidURL }

        let request = HTTPRequest(
            method: .get,
            url: url,
            headers: [
                "authorization": "Bearer \(token)",
                "appkey": appKey,
                "appsecret": appSecret,
                "tr_id": trID,
                "custtype": "P",
                "Content-Type": "application/json"
            ]
        )

        let data = try await http.send(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(String(describing: error))
        }
    }
}
