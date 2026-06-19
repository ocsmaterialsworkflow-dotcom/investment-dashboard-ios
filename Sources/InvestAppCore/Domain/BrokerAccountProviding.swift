import Foundation

/// 모든 증권사/거래소 저장소가 채택하는 공통 인터페이스.
///
/// 업비트(개념상 포함), 토스증권, 한국투자증권(KIS), NH 등
/// 각 연동 저장소는 이 프로토콜을 채택해 단일 `Account` 를 비동기로 제공한다.
/// DI 컨테이너/오케스트레이터는 `[BrokerAccountProviding]` 로 일괄 조회를 수행한다.
public protocol BrokerAccountProviding: Sendable {
    /// 이 저장소가 담당하는 증권사/거래소.
    var broker: Broker { get }

    /// 해당 증권사의 계좌 1개(보유 종목 포함)를 구성해 반환한다.
    func fetchAccount() async throws -> Account
}
