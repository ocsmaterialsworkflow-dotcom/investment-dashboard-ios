import XCTest
@testable import InvestAppCore

final class HoldingTests: XCTestCase {

    func test_krwHolding_evaluatedValueAndProfit() {
        let h = Holding(symbol: "BTC", name: "비트코인", market: .crypto,
                        quantity: 0.5, averageCost: 100_000_000, currentPrice: 120_000_000,
                        currency: .krw)
        XCTAssertEqual(h.evaluatedValue, 60_000_000, accuracy: 0.001)
        XCTAssertEqual(h.costBasis, 50_000_000, accuracy: 0.001)
        XCTAssertEqual(h.profitLoss, 10_000_000, accuracy: 0.001)
        XCTAssertEqual(h.profitLossRate, 20, accuracy: 0.0001)
    }

    func test_profitLossRate_zeroCostBasis_returnsZero() {
        let h = Holding(symbol: "X", name: "X", market: .crypto,
                        quantity: 0, averageCost: 0, currentPrice: 100, currency: .krw)
        XCTAssertEqual(h.profitLossRate, 0)
    }

    func test_usdHolding_convertsToKRWOnlyAtDisplay() {
        let h = Holding(symbol: "AAPL", name: "Apple", market: .usStock,
                        quantity: 10, averageCost: 150, currentPrice: 200, currency: .usd)
        // 원 통화 계산은 USD 유지
        XCTAssertEqual(h.evaluatedValue, 2000, accuracy: 0.001)
        // 표시 직전에만 환율 적용
        XCTAssertEqual(h.evaluatedValueKRW(usdToKrw: 1300), 2_600_000, accuracy: 0.001)
    }

    func test_krwHolding_ignoresExchangeRate() {
        let h = Holding(symbol: "BTC", name: "비트코인", market: .crypto,
                        quantity: 1, averageCost: 1, currentPrice: 1000, currency: .krw)
        XCTAssertEqual(h.evaluatedValueKRW(usdToKrw: 9999), 1000, accuracy: 0.001)
    }

    func test_account_totalValueKRW_sumsMixedCurrencies() {
        let krw = Holding(symbol: "BTC", name: "BTC", market: .crypto,
                          quantity: 1, averageCost: 1, currentPrice: 1_000_000, currency: .krw)
        let usd = Holding(symbol: "AAPL", name: "Apple", market: .usStock,
                          quantity: 10, averageCost: 100, currentPrice: 200, currency: .usd)
        let account = Account(broker: .upbit, accountType: .cryptoWallet, name: "테스트",
                              holdings: [krw, usd])
        // 1,000,000 + (2000 USD * 1300) = 1,000,000 + 2,600,000
        XCTAssertEqual(account.totalValueKRW(usdToKrw: 1300), 3_600_000, accuracy: 0.001)
    }
}
