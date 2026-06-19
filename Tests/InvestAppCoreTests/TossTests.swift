import XCTest
@testable import InvestAppCore

final class TossTests: XCTestCase {

    private func makeSecrets() -> InMemorySecretStore {
        InMemorySecretStore(seed: [.tossClientId: "cid", .tossClientSecret: "csecret"])
    }

    private let tokenJSON = """
    {"access_token":"toss-token","token_type":"Bearer","expires_in":86400}
    """

    // MARK: - Client / Auth

    func test_client_missingCredentials_throws() {
        let mock = MockHTTPClient { _ in Data() }
        XCTAssertThrowsError(try TossAPIClient(http: mock, secrets: InMemorySecretStore())) { error in
            XCTAssertEqual(error as? NetworkError, .missingCredentials)
        }
    }

    func test_fetchDomesticBalance_attachesBearerHeader() async throws {
        let balanceJSON = """
        {"holdings":[{"stock_code":"005930","stock_name":"삼성전자",
          "balance_qty":"10","avg_buy_price":"70000","current_price":"80000"}]}
        """
        let mock = MockHTTPClient { req in
            if req.url.absoluteString.contains("oauth2/token") {
                return Data(self.tokenJSON.utf8)
            }
            return Data(balanceJSON.utf8)
        }
        let client = try TossAPIClient(http: mock, secrets: makeSecrets())

        let response = try await client.fetchDomesticBalance()

        XCTAssertEqual(response.holdings.count, 1)
        XCTAssertEqual(response.holdings[0].quantity.value, 10)
        // 잔고 요청에 Bearer 헤더가 첨부되었는지 확인
        let balanceReq = mock.sentRequests.first { $0.url.absoluteString.contains("balance") }
        XCTAssertEqual(balanceReq?.headers["Authorization"], "Bearer toss-token")
    }

    // MARK: - Mapper

    func test_mapper_domestic_mapsKRStockKRW() {
        let response = TossDomesticBalanceResponse(holdings: [
            TossDomesticHolding(symbol: "005930", name: "삼성전자",
                                quantity: FlexibleDouble(10),
                                averagePrice: FlexibleDouble(70000),
                                currentPrice: FlexibleDouble(80000))
        ])
        let holdings = TossMapper.makeDomesticHoldings(response)
        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings[0].market, .krStock)
        XCTAssertEqual(holdings[0].currency, .krw)
        XCTAssertEqual(holdings[0].evaluatedValue, 800_000, accuracy: 0.001)
    }

    func test_mapper_overseas_mapsUSStockUSD() {
        let response = TossOverseasBalanceResponse(holdings: [
            TossOverseasHolding(symbol: "AAPL", name: "Apple Inc.",
                                quantity: FlexibleDouble(5),
                                averagePrice: FlexibleDouble(150),
                                currentPrice: FlexibleDouble(200),
                                currencyCode: "USD")
        ])
        let holdings = TossMapper.makeOverseasHoldings(response)
        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings[0].market, .usStock)
        XCTAssertEqual(holdings[0].currency, .usd)
    }

    func test_flexibleDouble_parsesStringOrNumber() throws {
        struct Box: Codable { let v: FlexibleDouble }
        let fromString = try JSONDecoder().decode(Box.self, from: Data("{\"v\":\"1,234.5\"}".utf8))
        let fromNumber = try JSONDecoder().decode(Box.self, from: Data("{\"v\":42.0}".utf8))
        XCTAssertEqual(fromString.v.value, 1234.5, accuracy: 0.001)
        XCTAssertEqual(fromNumber.v.value, 42, accuracy: 0.001)
    }

    // MARK: - Repository

    func test_repository_mergesDomesticAndOverseas() async throws {
        let domesticJSON = """
        {"holdings":[{"stock_code":"005930","stock_name":"삼성전자",
          "balance_qty":"10","avg_buy_price":"70000","current_price":"80000"}]}
        """
        let overseasJSON = """
        {"holdings":[{"ticker":"AAPL","stock_name":"Apple Inc.",
          "balance_qty":"5","avg_buy_price":"150","current_price":"200","currency":"USD"}]}
        """
        let mock = MockHTTPClient { req in
            let u = req.url.absoluteString
            if u.contains("oauth2/token") { return Data(self.tokenJSON.utf8) }
            if u.contains("overseas") { return Data(overseasJSON.utf8) }
            return Data(domesticJSON.utf8)
        }
        let client = try TossAPIClient(http: mock, secrets: makeSecrets())
        let repo = TossRepository(client: client)

        let account = try await repo.fetchAccount()

        XCTAssertEqual(account.broker, .tossSecurities)
        XCTAssertEqual(account.holdings.count, 2)
        XCTAssertTrue(account.holdings.contains { $0.currency == .krw && $0.market == .krStock })
        XCTAssertTrue(account.holdings.contains { $0.currency == .usd && $0.market == .usStock })
    }
}
