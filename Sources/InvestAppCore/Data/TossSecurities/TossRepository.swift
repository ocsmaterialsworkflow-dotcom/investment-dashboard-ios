import Foundation

/// 토스증권 데이터를 도메인 모델로 제공하는 저장소.
/// 국내 + 해외 잔고를 각각 조회해 하나의 `Account` 보유 종목으로 합친다.
public struct TossRepository: BrokerAccountProviding {

    public var broker: Broker { .tossSecurities }

    private let client: TossAPIClient
    private let accountName: String

    public init(client: TossAPIClient, accountName: String = "토스증권") {
        self.client = client
        self.accountName = accountName
    }

    /// 토스증권 계좌 1개(국내+해외 통합)를 구성해 반환한다.
    public func fetchAccount() async throws -> Account {
        let domestic = try await client.fetchDomesticBalance()
        let overseas = try await client.fetchOverseasBalance()

        let holdings = TossMapper.makeDomesticHoldings(domestic)
            + TossMapper.makeOverseasHoldings(overseas)

        return Account(
            broker: .tossSecurities,
            accountType: .general,
            name: accountName,
            holdings: holdings
        )
    }
}
