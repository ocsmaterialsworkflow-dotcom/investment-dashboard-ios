import XCTest
@testable import InvestAppCore

// MARK: - Mock

/// 요청별로 고정 응답을 돌려주는 목 HTTP 클라이언트 (환율 테스트 전용).
private final class MockHTTPClient: HTTPClient, @unchecked Sendable {
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

// MARK: - Stub Provider

/// 지정 값 또는 에러를 반환하는 스텁 `ExchangeRateProviding`.
private struct StubProvider: ExchangeRateProviding {
    enum Behavior {
        case success(Double)
        case failure(Error)
    }
    let behavior: Behavior

    func latestUSDKRW() async throws -> Double {
        switch behavior {
        case .success(let rate): return rate
        case .failure(let error): throw error
        }
    }
}

// MARK: - BOKExchangeRateClient Tests

final class BOKExchangeRateClientTests: XCTestCase {

    func test_latestUSDKRW_decodesNewestRow() async throws {
        // GIVEN: 여러 날짜 row 가 있을 때 가장 최신 TIME 의 값을 반환해야 함
        let json = """
        {
            "StatisticSearch": {
                "list_total_count": 2,
                "row": [
                    { "TIME": "20260617", "DATA_VALUE": "1375.0" },
                    { "TIME": "20260618", "DATA_VALUE": "1380.5" }
                ]
            }
        }
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = BOKExchangeRateClient(http: mock, apiKey: "TEST_KEY")

        let rate = try await client.latestUSDKRW()

        XCTAssertEqual(rate, 1380.5, accuracy: 0.001)
    }

    func test_latestUSDKRW_skipsEmptyDataValue_andReturnsNextValid() async throws {
        // GIVEN: 최신 row 의 DATA_VALUE 가 공백이면 다음 유효 row 사용
        let json = """
        {
            "StatisticSearch": {
                "list_total_count": 2,
                "row": [
                    { "TIME": "20260618", "DATA_VALUE": " " },
                    { "TIME": "20260617", "DATA_VALUE": "1375.0" }
                ]
            }
        }
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = BOKExchangeRateClient(http: mock, apiKey: "TEST_KEY")

        let rate = try await client.latestUSDKRW()

        XCTAssertEqual(rate, 1375.0, accuracy: 0.001)
    }

    func test_latestUSDKRW_urlContainsApiKeyAndDates() async throws {
        let json = """
        {
            "StatisticSearch": {
                "list_total_count": 1,
                "row": [{ "TIME": "20260618", "DATA_VALUE": "1380.0" }]
            }
        }
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = BOKExchangeRateClient(http: mock, apiKey: "MY_API_KEY")

        _ = try await client.latestUSDKRW()

        let urlString = mock.sentRequests.first?.url.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("MY_API_KEY"), "URL에 API 키가 포함되어야 함")
        XCTAssertTrue(urlString.contains("731Y001"), "통계표 코드 포함 확인")
        XCTAssertTrue(urlString.contains("0000001"), "항목 코드 포함 확인")
        XCTAssertEqual(mock.sentRequests.first?.method, .get)
    }

    func test_latestUSDKRW_errorEnvelope_throwsRequestFailed() async {
        // GIVEN: ECOS 에러 엔벨로프 응답
        let json = """
        {
            "RESULT": {
                "CODE": "INFO-200",
                "MESSAGE": "해당하는 데이터가 없습니다."
            }
        }
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = BOKExchangeRateClient(http: mock, apiKey: "BAD_KEY")

        do {
            _ = try await client.latestUSDKRW()
            XCTFail("에러 엔벨로프는 에러를 던져야 함")
        } catch {
            guard case NetworkError.requestFailed(let statusCode, let body) = error as? NetworkError else {
                return XCTFail("requestFailed 기대, 실제: \(error)")
            }
            XCTAssertEqual(statusCode, 0)
            XCTAssertTrue(body.contains("INFO-200") || body.contains("데이터가 없습니다"), "에러 메시지 포함 확인: \(body)")
        }
    }

    func test_latestUSDKRW_noValidRows_throwsDecodingFailed() async {
        // GIVEN: row 는 있으나 DATA_VALUE 가 모두 공백
        let json = """
        {
            "StatisticSearch": {
                "list_total_count": 1,
                "row": [{ "TIME": "20260618", "DATA_VALUE": " " }]
            }
        }
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = BOKExchangeRateClient(http: mock, apiKey: "TEST_KEY")

        do {
            _ = try await client.latestUSDKRW()
            XCTFail("유효한 row 없으면 에러를 던져야 함")
        } catch {
            guard case NetworkError.decodingFailed = error as? NetworkError else {
                return XCTFail("decodingFailed 기대, 실제: \(error)")
            }
        }
    }

    func test_latestUSDKRW_invalidJSON_throwsDecodingFailed() async {
        let mock = MockHTTPClient { _ in Data("not-json".utf8) }
        let client = BOKExchangeRateClient(http: mock, apiKey: "TEST_KEY")

        do {
            _ = try await client.latestUSDKRW()
            XCTFail("잘못된 JSON 은 에러를 던져야 함")
        } catch {
            guard case NetworkError.decodingFailed = error as? NetworkError else {
                return XCTFail("decodingFailed 기대, 실제: \(error)")
            }
        }
    }
}

// MARK: - FallbackExchangeRateClient Tests

final class FallbackExchangeRateClientTests: XCTestCase {

    func test_latestUSDKRW_decodesKRWRate() async throws {
        let json = """
        {
            "result": "success",
            "base_code": "USD",
            "rates": {
                "KRW": 1380.5,
                "EUR": 0.92
            }
        }
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = FallbackExchangeRateClient(http: mock)

        let rate = try await client.latestUSDKRW()

        XCTAssertEqual(rate, 1380.5, accuracy: 0.001)
    }

    func test_latestUSDKRW_usesCorrectEndpoint() async throws {
        let json = """
        { "result": "success", "rates": { "KRW": 1300.0 } }
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = FallbackExchangeRateClient(http: mock)

        _ = try await client.latestUSDKRW()

        let url = mock.sentRequests.first?.url.absoluteString ?? ""
        XCTAssertTrue(url.contains("open.er-api.com"), "open.er-api.com 엔드포인트 사용 확인")
        XCTAssertTrue(url.contains("USD"), "USD 기준 환율 조회 확인")
        XCTAssertEqual(mock.sentRequests.first?.method, .get)
    }

    func test_latestUSDKRW_resultNotSuccess_throwsRequestFailed() async {
        let json = """
        { "result": "error", "rates": {} }
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = FallbackExchangeRateClient(http: mock)

        do {
            _ = try await client.latestUSDKRW()
            XCTFail("result != success 이면 에러를 던져야 함")
        } catch {
            guard case NetworkError.requestFailed = error as? NetworkError else {
                return XCTFail("requestFailed 기대, 실제: \(error)")
            }
        }
    }

    func test_latestUSDKRW_missingKRWKey_throwsDecodingFailed() async {
        let json = """
        { "result": "success", "rates": { "EUR": 0.92 } }
        """.data(using: .utf8)!

        let mock = MockHTTPClient { _ in json }
        let client = FallbackExchangeRateClient(http: mock)

        do {
            _ = try await client.latestUSDKRW()
            XCTFail("KRW 키 없으면 에러를 던져야 함")
        } catch {
            guard case NetworkError.decodingFailed = error as? NetworkError else {
                return XCTFail("decodingFailed 기대, 실제: \(error)")
            }
        }
    }

    func test_latestUSDKRW_invalidJSON_throwsDecodingFailed() async {
        let mock = MockHTTPClient { _ in Data("garbage".utf8) }
        let client = FallbackExchangeRateClient(http: mock)

        do {
            _ = try await client.latestUSDKRW()
            XCTFail("잘못된 JSON 은 에러를 던져야 함")
        } catch {
            guard case NetworkError.decodingFailed = error as? NetworkError else {
                return XCTFail("decodingFailed 기대, 실제: \(error)")
            }
        }
    }
}

// MARK: - ExchangeRateRepository Tests

final class ExchangeRateRepositoryTests: XCTestCase {

    func test_usesPrimaryWhenSucceeds() async throws {
        let primary = StubProvider(behavior: .success(1380.5))
        let fallback = StubProvider(behavior: .success(9999.0))
        let repo = ExchangeRateRepository(primary: primary, fallback: fallback)

        let rate = try await repo.latestUSDKRW()

        XCTAssertEqual(rate, 1380.5, accuracy: 0.001, "primary 가 성공하면 primary 값 반환")
    }

    func test_usesFallbackWhenPrimaryFails() async throws {
        let primary = StubProvider(behavior: .failure(NetworkError.rateLimited))
        let fallback = StubProvider(behavior: .success(1375.0))
        let repo = ExchangeRateRepository(primary: primary, fallback: fallback)

        let rate = try await repo.latestUSDKRW()

        XCTAssertEqual(rate, 1375.0, accuracy: 0.001, "primary 실패 시 fallback 값 반환")
    }

    func test_throwsWhenBothFail() async {
        let primary = StubProvider(behavior: .failure(NetworkError.rateLimited))
        let fallback = StubProvider(behavior: .failure(NetworkError.transport("timeout")))
        let repo = ExchangeRateRepository(primary: primary, fallback: fallback)

        do {
            _ = try await repo.latestUSDKRW()
            XCTFail("primary, fallback 모두 실패하면 에러를 던져야 함")
        } catch {
            // 에러 타입은 fallback 이 던진 것
            guard case NetworkError.transport = error as? NetworkError else {
                return XCTFail("transport 에러 기대, 실제: \(error)")
            }
        }
    }
}

// MARK: - ExchangeRateManager Tests

@MainActor
final class ExchangeRateManagerTests: XCTestCase {

    func test_refresh_updatesUsdToKrw() async {
        let provider = StubProvider(behavior: .success(1380.5))
        let manager = ExchangeRateManager(provider: provider)

        XCTAssertEqual(manager.usdToKrw, 1300.0, "초기값 1300.0 확인")
        XCTAssertNil(manager.lastUpdated)

        await manager.refresh()

        XCTAssertEqual(manager.usdToKrw, 1380.5, accuracy: 0.001)
        XCTAssertNotNil(manager.lastUpdated)
    }

    func test_refresh_isLoadingTransition() async {
        let provider = StubProvider(behavior: .success(1380.0))
        let manager = ExchangeRateManager(provider: provider)

        XCTAssertFalse(manager.isLoading)
        await manager.refresh()
        XCTAssertFalse(manager.isLoading, "refresh 완료 후 isLoading 은 false 여야 함")
    }

    func test_refresh_onError_keepsLastGoodValue() async {
        let provider = StubProvider(behavior: .failure(NetworkError.rateLimited))
        let manager = ExchangeRateManager(provider: provider)

        // 기본값 유지
        await manager.refresh()

        XCTAssertEqual(manager.usdToKrw, 1300.0, "에러 시 기본값 유지")
        XCTAssertNil(manager.lastUpdated, "에러 시 lastUpdated 미갱신")
        XCTAssertFalse(manager.isLoading, "에러 후에도 isLoading = false")
    }

    func test_refresh_onError_afterSuccessKeepsPreviousRate() async {
        // 첫 번째 호출 성공 → 두 번째 에러 → 이전 값 유지
        var callCount = 0
        struct ToggleProvider: ExchangeRateProviding {
            let counter: () -> Int
            func latestUSDKRW() async throws -> Double {
                let n = counter()
                if n == 1 { return 1380.5 }
                throw NetworkError.transport("서버 다운")
            }
        }
        let provider = ToggleProvider { callCount += 1; return callCount }
        let manager = ExchangeRateManager(provider: provider)

        await manager.refresh() // success → 1380.5
        XCTAssertEqual(manager.usdToKrw, 1380.5, accuracy: 0.001)

        await manager.refresh() // failure → keep 1380.5
        XCTAssertEqual(manager.usdToKrw, 1380.5, accuracy: 0.001, "에러 시 이전 성공 값 유지")
    }

    func test_convert_multipliesUsdByRate() {
        let provider = StubProvider(behavior: .success(1380.0))
        let manager = ExchangeRateManager(provider: provider)
        manager.usdToKrw = 1380.0

        let result = manager.convert(usd: 100.0)

        XCTAssertEqual(result, 138_000.0, accuracy: 0.001)
    }

    func test_convert_zeroUSD() {
        let provider = StubProvider(behavior: .success(1380.0))
        let manager = ExchangeRateManager(provider: provider)
        manager.usdToKrw = 1380.0

        XCTAssertEqual(manager.convert(usd: 0), 0)
    }
}

// MARK: - CurrencyFormat Tests

final class CurrencyFormatTests: XCTestCase {

    func test_formattedKRW_largeNumber() {
        let result = CurrencyFormat.formattedKRW(279_149_692)
        XCTAssertEqual(result, "279,149,692원")
    }

    func test_formattedKRW_zero() {
        let result = CurrencyFormat.formattedKRW(0)
        XCTAssertEqual(result, "0원")
    }

    func test_formattedKRW_smallNumber() {
        let result = CurrencyFormat.formattedKRW(1000)
        XCTAssertEqual(result, "1,000원")
    }

    func test_formattedKRW_noDecimals() {
        // 소수점 없이 반올림해야 함
        let result = CurrencyFormat.formattedKRW(1000.9)
        // NumberFormatter maximumFractionDigits=0 은 반올림
        XCTAssertEqual(result, "1,001원")
    }

    func test_formattedSignedKRW_positive() {
        let result = CurrencyFormat.formattedSignedKRW(32_323_665)
        XCTAssertEqual(result, "+32,323,665원")
    }

    func test_formattedSignedKRW_negative() {
        let result = CurrencyFormat.formattedSignedKRW(-1_000)
        XCTAssertEqual(result, "-1,000원")
    }

    func test_formattedSignedKRW_zero() {
        let result = CurrencyFormat.formattedSignedKRW(0)
        // 0 은 양수로 취급 (+)
        XCTAssertEqual(result, "+0원")
    }

    func test_formattedPercent_positive() {
        let result = CurrencyFormat.formattedPercent(13.10)
        XCTAssertEqual(result, "+13.10%")
    }

    func test_formattedPercent_negative() {
        let result = CurrencyFormat.formattedPercent(-5.3)
        XCTAssertEqual(result, "-5.30%")
    }

    func test_formattedPercent_zero() {
        let result = CurrencyFormat.formattedPercent(0)
        XCTAssertEqual(result, "+0.00%")
    }

    func test_formattedPercent_twoDecimalPlaces() {
        let result = CurrencyFormat.formattedPercent(1.0 / 3.0)
        // 0.333... → "+0.33%"
        XCTAssertEqual(result, "+0.33%")
    }
}
