import XCTest
@testable import InvestAppCore

final class NHBridgeTests: XCTestCase {

    func test_fetchAccount_throwsUnsupportedTransportError() async {
        let provider = NHBridgeAccountProvider()
        do {
            _ = try await provider.fetchAccount()
            XCTFail("NH 직접 연동은 미지원이므로 에러를 던져야 함")
        } catch {
            XCTAssertEqual(
                error as? NetworkError,
                .transport("NH 직접 연동 미지원 — 백엔드 브릿지 필요")
            )
        }
    }

    func test_fetchAccount_withBridgeURL_stillThrows() async {
        // 브릿지 URL 을 주입해도 실제 구현 전까지는 동일하게 미지원.
        let provider = NHBridgeAccountProvider(bridgeBaseURL: URL(string: "https://bridge.example.com"))
        do {
            _ = try await provider.fetchAccount()
            XCTFail("브릿지 미구현 상태에서는 에러를 던져야 함")
        } catch {
            guard case NetworkError.transport = (error as? NetworkError) ?? .invalidURL else {
                return XCTFail("transport 에러 기대, 실제: \(error)")
            }
        }
    }

    func test_conformsToBrokerAccountProviding() {
        let provider: BrokerAccountProviding = NHBridgeAccountProvider()
        XCTAssertEqual(provider.broker, .kis)
    }
}
