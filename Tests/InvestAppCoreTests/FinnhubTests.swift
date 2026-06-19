import XCTest
@testable import InvestAppCore

final class FinnhubTests: XCTestCase {

    private func utcDate(_ iso: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: iso)!
    }

    func test_quote_decodesCurrentPrice_andAppendsToken() async throws {
        let json = Data(#"{"c":200.15,"h":201,"l":199,"o":200,"pc":198}"#.utf8)
        let mock = MockHTTPClient { _ in json }
        let client = FinnhubClient(http: mock, apiKey: "KEY123")

        let price = try await client.quote(symbol: "AAPL")

        XCTAssertEqual(price, 200.15, accuracy: 0.001)
        let url = mock.sentRequests.first?.url.absoluteString ?? ""
        XCTAssertTrue(url.contains("/quote"))
        XCTAssertTrue(url.contains("symbol=AAPL"))
        XCTAssertTrue(url.contains("token=KEY123"))
    }

    func test_dividends_mapsToSchedule_withZeroTotal_andDateQuery() async throws {
        let json = Data("""
        [{"symbol":"AAPL","date":"2025-02-07","payDate":"2025-02-13","amount":0.24}]
        """.utf8)
        let mock = MockHTTPClient { _ in json }
        let client = FinnhubClient(http: mock, apiKey: "KEY")

        let from = utcDate("2025-01-01")
        let to = utcDate("2025-12-31")
        let schedules = try await client.dividends(symbol: "AAPL", from: from, to: to)

        XCTAssertEqual(schedules.count, 1)
        let s = schedules[0]
        XCTAssertEqual(s.symbol, "AAPL")
        XCTAssertEqual(s.amountPerShare, 0.24, accuracy: 0.0001)
        XCTAssertEqual(s.totalAmount, 0)
        XCTAssertTrue(s.isConfirmed)
        XCTAssertEqual(s.exDividendDate, utcDate("2025-02-07"))
        XCTAssertEqual(s.paymentDate, utcDate("2025-02-13"))

        let url = mock.sentRequests.first?.url.absoluteString ?? ""
        XCTAssertTrue(url.contains("/stock/dividend"))
        XCTAssertTrue(url.contains("from=2025-01-01"))
        XCTAssertTrue(url.contains("to=2025-12-31"))
        XCTAssertTrue(url.contains("token=KEY"))
    }

    func test_dividends_empty() async throws {
        let mock = MockHTTPClient { _ in Data("[]".utf8) }
        let client = FinnhubClient(http: mock, apiKey: "KEY")
        let schedules = try await client.dividends(symbol: "AAPL", from: Date(), to: Date())
        XCTAssertTrue(schedules.isEmpty)
    }

    func test_quote_decodingFailure_throws() async {
        let mock = MockHTTPClient { _ in Data("not-json".utf8) }
        let client = FinnhubClient(http: mock, apiKey: "KEY")
        do {
            _ = try await client.quote(symbol: "AAPL")
            XCTFail("디코딩 실패 시 에러를 던져야 함")
        } catch {
            guard case NetworkError.decodingFailed = (error as? NetworkError) ?? .invalidURL else {
                return XCTFail("decodingFailed 기대, 실제: \(error)")
            }
        }
    }
}
