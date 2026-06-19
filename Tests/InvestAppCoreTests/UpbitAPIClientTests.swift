import XCTest
@testable import InvestAppCore

/// 요청별로 고정 응답을 돌려주는 목 HTTP 클라이언트. 마지막 요청을 기록한다.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var responder: (HTTPRequest) throws -> Data
    private(set) var sentRequests: [HTTPRequest] = []
    private let lock = NSLock()

    init(responder: @escaping (HTTPRequest) throws -> Data) {
        self.responder = responder
    }

    func send(_ request: HTTPRequest) async throws -> Data {
        lock.lock(); sentRequests.append(request); lock.unlock()
        return try responder(request)
    }
}

final class UpbitAPIClientTests: XCTestCase {

    private func makeSecrets() -> InMemorySecretStore {
        InMemorySecretStore(seed: [.upbitAccessKey: "ak", .upbitSecretKey: "sk"])
    }

    func test_fetchAccounts_attachesBearerToken_andDecodes() async throws {
        let json = """
        [{"currency":"BTC","balance":"0.01","locked":"0.005","avg_buy_price":"95000000",
          "avg_buy_price_modified":false,"unit_currency":"KRW"}]
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = UpbitAPIClient(http: mock, secrets: makeSecrets())

        let accounts = try await client.fetchAccounts()

        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].currency, "BTC")
        // 인증 헤더 존재 + Bearer 형식
        let auth = mock.sentRequests.first?.headers["Authorization"]
        XCTAssertNotNil(auth)
        XCTAssertTrue(auth?.hasPrefix("Bearer ") == true)
        XCTAssertEqual(auth?.split(separator: ".").count, 3) // JWT 3-세그먼트
    }

    func test_fetchAccounts_withoutCredentials_throwsMissingCredentials() async {
        let mock = MockHTTPClient { _ in Data("[]".utf8) }
        let client = UpbitAPIClient(http: mock, secrets: InMemorySecretStore())

        do {
            _ = try await client.fetchAccounts()
            XCTFail("자격증명 없으면 에러를 던져야 함")
        } catch {
            XCTAssertEqual(error as? NetworkError, .missingCredentials)
        }
    }

    func test_fetchTickers_noAuthHeader_andBuildsMarketsQuery() async throws {
        let json = """
        [{"market":"KRW-BTC","trade_price":100000000.0}]
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = UpbitAPIClient(http: mock, secrets: makeSecrets())

        let tickers = try await client.fetchTickers(markets: ["KRW-BTC", "KRW-ETH"])

        XCTAssertEqual(tickers.first?.tradePrice, 100_000_000)
        let url = mock.sentRequests.first?.url.absoluteString ?? ""
        XCTAssertTrue(url.contains("markets=KRW-BTC,KRW-ETH"))
        XCTAssertNil(mock.sentRequests.first?.headers["Authorization"])
    }

    func test_fetchTickers_emptyMarkets_returnsEmpty_withoutRequest() async throws {
        let mock = MockHTTPClient { _ in Data() }
        let client = UpbitAPIClient(http: mock, secrets: makeSecrets())

        let tickers = try await client.fetchTickers(markets: [])
        XCTAssertTrue(tickers.isEmpty)
        XCTAssertTrue(mock.sentRequests.isEmpty)
    }

    func test_repository_fetchAccount_mergesBalancesAndPrices() async throws {
        let accountsJSON = """
        [{"currency":"BTC","balance":"0.01","locked":"0.00520187","avg_buy_price":"95000000",
          "avg_buy_price_modified":false,"unit_currency":"KRW"},
         {"currency":"KRW","balance":"1000000","locked":"0","avg_buy_price":"0",
          "avg_buy_price_modified":false,"unit_currency":"KRW"}]
        """
        let tickerJSON = """
        [{"market":"KRW-BTC","trade_price":100000000.0}]
        """

        let mock = MockHTTPClient { req in
            if req.url.absoluteString.contains("ticker") {
                return Data(tickerJSON.utf8)
            }
            return Data(accountsJSON.utf8)
        }
        let repo = UpbitRepository(client: UpbitAPIClient(http: mock, secrets: makeSecrets()))

        let account = try await repo.fetchAccount()

        XCTAssertEqual(account.broker, .upbit)
        XCTAssertEqual(account.holdings.count, 1) // KRW 현금 제외
        XCTAssertEqual(account.holdings[0].symbol, "BTC")
        XCTAssertEqual(account.holdings[0].currentPrice, 100_000_000, accuracy: 0.001)
        // 평가금액 = 0.01520187 * 100,000,000
        XCTAssertEqual(account.totalValueKRW(usdToKrw: 1300), 1_520_187, accuracy: 1)
    }

    func test_decodingFailure_throwsDecodingError() async {
        let mock = MockHTTPClient { _ in Data("not-json".utf8) }
        let client = UpbitAPIClient(http: mock, secrets: makeSecrets())
        do {
            _ = try await client.fetchAccounts()
            XCTFail("디코딩 실패 시 에러를 던져야 함")
        } catch {
            guard case NetworkError.decodingFailed = (error as? NetworkError) ?? .invalidURL else {
                return XCTFail("decodingFailed 기대, 실제: \(error)")
            }
        }
    }
}
