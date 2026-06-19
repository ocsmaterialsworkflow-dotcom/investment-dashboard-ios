import Foundation

/// `UpbitRepository` 는 Phase 2 에서 `BrokerAccountProviding` 프로토콜보다 먼저 작성되었으므로
/// 여기서 공통 인터페이스 적합성을 추가한다. `fetchAccount()` 는 이미 동일 시그니처로 구현되어 있다.
extension UpbitRepository: BrokerAccountProviding {
    public var broker: Broker { .upbit }
}
