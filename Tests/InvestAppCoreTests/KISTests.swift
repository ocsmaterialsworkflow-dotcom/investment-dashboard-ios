import XCTest
@testable import InvestAppCore

final class KISTests: XCTestCase {

    private func makeSecrets() -> InMemorySecretStore {
        InMemorySecretStore(seed: [.kisAppKey: "ak", .kisAppSecret: "as"])
    }

    private let tokenJSON = """
    {"access_token":"kis-token","token_type":"Bearer","expires_in":86400,
     "access_token_token_expired":"2026-06-20 12:00:00"}
    """

    // MARK: - Auth / headers

    func test_authClient_missingCredentials_throws() {
        let mock = MockHTTPClient { _ in Data() }
        XCTAssertThrowsError(try KISAuthClient(http: mock, secrets: InMemorySecretStore())) { error in
            XCTAssertEqual(error as? NetworkError, .missingCredentials)
        }
    }

    func test_fetchDomesticBalance_sendsRequiredHeaders() async throws {
        let balanceJSON = """
        {"rt_cd":"0","msg1":"정상","output1":[
          {"pdno":"005930","prdt_name":"삼성전자","hldg_qty":"10",
           "pchs_avg_pric":"70000","prpr":"80000"}]}
        """
        let mock = MockHTTPClient { req in
            if req.url.absoluteString.contains("oauth2/tokenP") {
                return Data(self.tokenJSON.utf8)
            }
            return Data(balanceJSON.utf8)
        }
        let client = try KISAPIClient(http: mock, secrets: makeSecrets(), accountNo: "12345678-01")

        let response = try await client.fetchDomesticBalance()

        XCTAssertEqual(response.output1?.count, 1)
        let balanceReq = try XCTUnwrap(mock.sentRequests.first { $0.url.absoluteString.contains("inquire-balance") })
        XCTAssertEqual(balanceReq.headers["authorization"], "Bearer kis-token")
        XCTAssertEqual(balanceReq.headers["appkey"], "ak")
        XCTAssertEqual(balanceReq.headers["appsecret"], "as")
        XCTAssertEqual(balanceReq.headers["tr_id"], "TTTC8434R")
        XCTAssertEqual(balanceReq.headers["custtype"], "P")
        // 계좌번호 분리 확인
        XCTAssertTrue(balanceReq.url.absoluteString.contains("CANO=12345678"))
        XCTAssertTrue(balanceReq.url.absoluteString.contains("ACNT_PRDT_CD=01"))
    }

    func test_fetchOverseasBalance_usesOverseasTRID() async throws {
        let balanceJSON = """
        {"rt_cd":"0","output1":[]}
        """
        let mock = MockHTTPClient { req in
            if req.url.absoluteString.contains("oauth2/tokenP") {
                return Data(self.tokenJSON.utf8)
            }
            return Data(balanceJSON.utf8)
        }
        let client = try KISAPIClient(http: mock, secrets: makeSecrets(), accountNo: "12345678-01")

        _ = try await client.fetchOverseasBalance()

        let balanceReq = try XCTUnwrap(mock.sentRequests.first { $0.url.absoluteString.contains("overseas-stock") })
        XCTAssertEqual(balanceReq.headers["tr_id"], "TTTS3012R")
    }

    // MARK: - Mapper

    func test_mapper_domestic_parsesStringNumbers() {
        let response = KISDomesticBalanceResponse(
            output1: [KISDomesticHolding(symbol: "005930", name: "삼성전자",
                                         quantity: "10", averagePrice: "70000", currentPrice: "80000")],
            rtCd: "0", msg1: nil
        )
        let holdings = KISMapper.makeDomesticHoldings(response)
        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings[0].market, .krStock)
        XCTAssertEqual(holdings[0].currency, .krw)
        XCTAssertEqual(holdings[0].quantity, 10, accuracy: 0.001)
        XCTAssertEqual(holdings[0].currentPrice, 80000, accuracy: 0.001)
    }

    func test_mapper_overseas_mapsUSStockUSD() {
        let response = KISOverseasBalanceResponse(
            output1: [KISOverseasHolding(symbol: "AAPL", name: "Apple", quantity: "5",
                                         averagePrice: "150", currentPrice: "200", currencyCode: "USD")],
            rtCd: "0", msg1: nil
        )
        let holdings = KISMapper.makeOverseasHoldings(response)
        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings[0].market, .usStock)
        XCTAssertEqual(holdings[0].currency, .usd)
    }

    func test_mapper_excludesZeroQuantity() {
        let response = KISDomesticBalanceResponse(
            output1: [KISDomesticHolding(symbol: "X", name: "x", quantity: "0",
                                         averagePrice: "1", currentPrice: "1")],
            rtCd: "0", msg1: nil
        )
        XCTAssertTrue(KISMapper.makeDomesticHoldings(response).isEmpty)
    }

    // MARK: - Repository

    func test_repository_mergesDomesticAndOverseas() async throws {
        let domesticJSON = """
        {"rt_cd":"0","output1":[{"pdno":"005930","prdt_name":"삼성전자","hldg_qty":"10",
          "pchs_avg_pric":"70000","prpr":"80000"}]}
        """
        let overseasJSON = """
        {"rt_cd":"0","output1":[{"ovrs_pdno":"AAPL","ovrs_item_name":"Apple","ovrs_cblc_qty":"5",
          "pchs_avg_pric":"150","now_pric2":"200","tr_crcy_cd":"USD"}]}
        """
        let mock = MockHTTPClient { req in
            let u = req.url.absoluteString
            if u.contains("oauth2/tokenP") { return Data(self.tokenJSON.utf8) }
            if u.contains("overseas-stock") { return Data(overseasJSON.utf8) }
            return Data(domesticJSON.utf8)
        }
        let client = try KISAPIClient(http: mock, secrets: makeSecrets(), accountNo: "12345678-01")
        let repo = KISRepository(client: client)

        let account = try await repo.fetchAccount()

        XCTAssertEqual(account.broker, .kis)
        XCTAssertEqual(account.holdings.count, 2)
        XCTAssertTrue(account.holdings.contains { $0.currency == .krw })
        XCTAssertTrue(account.holdings.contains { $0.currency == .usd })
    }
}
