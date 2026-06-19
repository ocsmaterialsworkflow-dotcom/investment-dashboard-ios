import XCTest
@testable import InvestAppCore

final class OAuth2Tests: XCTestCase {

    private let tokenURL = URL(string: "https://example.com/oauth2/token")!

    func test_token_cachesAndReusesUntilExpiry() async throws {
        var callCount = 0
        let mock = MockHTTPClient { _ in
            callCount += 1
            return Data("""
            {"access_token":"tok-\(callCount)","token_type":"Bearer","expires_in":86400}
            """.utf8)
        }
        let provider = OAuth2TokenProvider(
            http: mock, tokenURL: tokenURL, clientId: "id", clientSecret: "secret"
        )

        let first = try await provider.token()
        let second = try await provider.token()

        XCTAssertEqual(first, "tok-1")
        XCTAssertEqual(second, "tok-1")   // 캐시 재사용
        XCTAssertEqual(callCount, 1)      // 네트워크 1회만
    }

    func test_token_refreshesWhenExpired() async throws {
        var callCount = 0
        let mock = MockHTTPClient { _ in
            callCount += 1
            // expires_in 0 → 항상 만료 → 매번 재발급
            return Data("""
            {"access_token":"tok-\(callCount)","token_type":"Bearer","expires_in":0}
            """.utf8)
        }
        let provider = OAuth2TokenProvider(
            http: mock, tokenURL: tokenURL, clientId: "id", clientSecret: "secret"
        )

        let first = try await provider.token()
        let second = try await provider.token()

        XCTAssertEqual(first, "tok-1")
        XCTAssertEqual(second, "tok-2")
        XCTAssertEqual(callCount, 2)
    }

    func test_token_sendsClientCredentialsFormBody() async throws {
        let mock = MockHTTPClient { _ in
            Data("""
            {"access_token":"abc","token_type":"Bearer","expires_in":3600}
            """.utf8)
        }
        let provider = OAuth2TokenProvider(
            http: mock, tokenURL: tokenURL, clientId: "myid", clientSecret: "mysecret"
        )

        _ = try await provider.token()

        let request = try XCTUnwrap(mock.sentRequests.first)
        XCTAssertEqual(request.method, .post)
        let body = String(data: try XCTUnwrap(request.body), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("grant_type=client_credentials"))
        XCTAssertTrue(body.contains("client_id=myid"))
        XCTAssertTrue(body.contains("client_secret=mysecret"))
    }

    func test_token_decodingFailure_throws() async {
        let mock = MockHTTPClient { _ in Data("not-json".utf8) }
        let provider = OAuth2TokenProvider(
            http: mock, tokenURL: tokenURL, clientId: "id", clientSecret: "secret"
        )
        do {
            _ = try await provider.token()
            XCTFail("디코딩 실패 시 에러를 던져야 함")
        } catch {
            guard case NetworkError.decodingFailed = (error as? NetworkError) ?? .invalidURL else {
                return XCTFail("decodingFailed 기대, 실제: \(error)")
            }
        }
    }
}
