import Foundation

/// NH투자증권 연동 자리표시자(placeholder) 저장소.
///
/// NH투자증권의 QV Open API 는 **Windows 전용 DLL** 형태로만 제공되어
/// iOS 앱에서 직접 호출할 수 없다. 따라서 이 provider 는 다음 중 하나의
/// **외부 브릿지 백엔드**를 전제로 한 자리표시자다:
/// - 자체 서버에서 NH DLL 을 구동하고 REST 로 중계하는 브릿지, 또는
/// - CODEF 같은 계좌 집계(Open Banking aggregation) API.
///
/// 브릿지가 마련되기 전까지 `fetchAccount()` 는 명시적 오류를 던진다.
/// `bridgeBaseURL` 을 주입하면 향후 백엔드 연동을 끼워 넣을 수 있도록 시그니처를 열어둔다.
public struct NHBridgeAccountProvider: BrokerAccountProviding {

    public var broker: Broker { .nhInvestment }

    /// 향후 브릿지 백엔드 / 집계 API 의 기준 URL. 현재는 사용되지 않는다.
    private let bridgeBaseURL: URL?

    public init(bridgeBaseURL: URL? = nil) {
        self.bridgeBaseURL = bridgeBaseURL
    }

    /// 항상 미지원 오류를 던진다. 브릿지 백엔드가 준비되면 이 구현을 교체한다.
    public func fetchAccount() async throws -> Account {
        throw NetworkError.transport("NH 직접 연동 미지원 — 백엔드 브릿지 필요")
    }
}
