import XCTest
@testable import InvestAppCore

final class UpbitMapperTests: XCTestCase {

    private func account(_ currency: String, balance: String, locked: String = "0",
                         avg: String) -> UpbitAccount {
        UpbitAccount(currency: currency, balance: balance, locked: locked,
                     avgBuyPrice: avg, avgBuyPriceModified: false, unitCurrency: "KRW")
    }

    func test_makeHoldings_combinesBalanceAndTicker() {
        let accounts = [
            account("BTC", balance: "0.01", locked: "0.00520187", avg: "95000000"),
            account("KRW", balance: "1000000", avg: "0") // 현금은 제외돼야 함
        ]
        let tickers = [UpbitTicker(market: "KRW-BTC", tradePrice: 100_000_000)]

        let holdings = UpbitMapper.makeHoldings(accounts: accounts, tickers: tickers)

        XCTAssertEqual(holdings.count, 1)
        let btc = holdings[0]
        XCTAssertEqual(btc.symbol, "BTC")
        XCTAssertEqual(btc.quantity, 0.01520187, accuracy: 1e-9)
        XCTAssertEqual(btc.currentPrice, 100_000_000, accuracy: 0.001)
        XCTAssertEqual(btc.averageCost, 95_000_000, accuracy: 0.001)
    }

    func test_makeHoldings_missingTicker_fallsBackToAvgPrice() {
        let accounts = [account("ETH", balance: "2", avg: "3000000")]
        let holdings = UpbitMapper.makeHoldings(accounts: accounts, tickers: [])
        XCTAssertEqual(holdings.count, 1)
        // 현재가를 못 찾으면 평단가 사용 → 손익 0
        XCTAssertEqual(holdings[0].currentPrice, 3_000_000, accuracy: 0.001)
        XCTAssertEqual(holdings[0].profitLoss, 0, accuracy: 0.001)
    }

    func test_makeHoldings_excludesZeroQuantity() {
        let accounts = [account("DOGE", balance: "0", locked: "0", avg: "100")]
        XCTAssertTrue(UpbitMapper.makeHoldings(accounts: accounts, tickers: []).isEmpty)
    }

    func test_krwCashBalance_sumsFiatOnly() {
        let accounts = [
            account("KRW", balance: "1000000", locked: "500000", avg: "0"),
            account("BTC", balance: "1", avg: "100")
        ]
        XCTAssertEqual(UpbitMapper.krwCashBalance(accounts: accounts), 1_500_000, accuracy: 0.001)
    }
}
