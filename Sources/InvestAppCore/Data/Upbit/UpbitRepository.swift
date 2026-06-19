import Foundation

/// 업비트 데이터를 도메인 모델로 제공하는 저장소.
/// 잔고 조회 → 보유 코인의 마켓 현재가 조회 → 보유 종목 변환을 한 번에 수행한다.
public struct UpbitRepository: Sendable {

    private let client: UpbitAPIClient

    public init(client: UpbitAPIClient) {
        self.client = client
    }

    /// 업비트 계좌 1개(코인 지갑)를 구성해 반환한다.
    public func fetchAccount() async throws -> Account {
        let accounts = try await client.fetchAccounts()

        // 코인 보유분의 마켓 코드만 추려 현재가 조회 (KRW 현금 제외)
        let markets = accounts
            .filter { !$0.isFiat && $0.totalQuantity > 0 }
            .map(\.krwMarketCode)

        let tickers = markets.isEmpty ? [] : try await client.fetchTickers(markets: markets)
        let holdings = UpbitMapper.makeHoldings(accounts: accounts, tickers: tickers)

        return Account(
            broker: .upbit,
            accountType: .cryptoWallet,
            name: "업비트",
            holdings: holdings
        )
    }
}
