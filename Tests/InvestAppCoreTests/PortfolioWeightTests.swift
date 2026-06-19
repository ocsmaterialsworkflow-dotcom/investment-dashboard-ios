import XCTest
@testable import InvestAppCore

final class PortfolioWeightTests: XCTestCase {

    // KRW 주식: 평가 10*120 = 1200
    private func krStock() -> Holding {
        Holding(symbol: "005930", name: "삼성전자", market: .krStock,
                quantity: 10, averageCost: 100, currentPrice: 120, currency: .krw)
    }
    // USD 주식: 평가 2*15 = 30 USD → 1300 환율 → 39000
    private func usStock() -> Holding {
        Holding(symbol: "AAPL", name: "Apple", market: .usStock,
                quantity: 2, averageCost: 10, currentPrice: 15, currency: .usd)
    }
    // 코인: 평가 0.1*100000 = 10000 KRW
    private func coin() -> Holding {
        Holding(symbol: "BTC", name: "BTC", market: .crypto,
                quantity: 0.1, averageCost: 90_000, currentPrice: 100_000, currency: .krw)
    }

    private func accounts() -> [Account] {
        [
            Account(broker: .kis, accountType: .general, name: "증권", holdings: [krStock(), usStock()]),
            Account(broker: .upbit, accountType: .cryptoWallet, name: "업비트", holdings: [coin()])
        ]
    }

    private func assertPercentSums100(_ slices: [WeightSlice]) {
        let sum = slices.reduce(0) { $0 + $1.percent }
        XCTAssertEqual(sum, 100, accuracy: 0.001)
    }

    func test_holding_dimension_sumsTo100_andSorted() {
        let sut = PortfolioWeightUseCase()
        let slices = sut.weights(accounts: accounts(), dimension: .holding, usdToKrw: 1300)
        XCTAssertEqual(slices.count, 3)
        assertPercentSums100(slices)
        // 내림차순: AAPL(39000) > 코인(10000) > 삼성(1200)
        XCTAssertEqual(slices.map { $0.label }, ["Apple", "BTC", "삼성전자"])
    }

    func test_type_dimension_groupsStockAndCoin() {
        let sut = PortfolioWeightUseCase()
        let slices = sut.weights(accounts: accounts(), dimension: .type, usdToKrw: 1300)
        assertPercentSums100(slices)
        // 주식 = 1200 + 39000 = 40200, 코인 = 10000
        let stock = slices.first { $0.label == "주식" }
        let coinSlice = slices.first { $0.label == "코인" }
        XCTAssertEqual(stock?.valueKRW, 40_200, accuracy: 0.001)
        XCTAssertEqual(coinSlice?.valueKRW, 10_000, accuracy: 0.001)
    }

    func test_country_dimension() {
        let sut = PortfolioWeightUseCase()
        let slices = sut.weights(accounts: accounts(), dimension: .country, usdToKrw: 1300)
        assertPercentSums100(slices)
        XCTAssertEqual(slices.first { $0.label == "미국" }?.valueKRW, 39_000, accuracy: 0.001)
        XCTAssertEqual(slices.first { $0.label == "한국" }?.valueKRW, 1_200, accuracy: 0.001)
        XCTAssertEqual(slices.first { $0.label == "코인" }?.valueKRW, 10_000, accuracy: 0.001)
    }

    func test_account_dimension() {
        let sut = PortfolioWeightUseCase()
        let slices = sut.weights(accounts: accounts(), dimension: .account, usdToKrw: 1300)
        XCTAssertEqual(slices.count, 2)
        assertPercentSums100(slices)
        // 증권 = 40200, 업비트 = 10000
        XCTAssertEqual(slices.first { $0.label == "증권" }?.valueKRW, 40_200, accuracy: 0.001)
    }

    func test_exchange_dimension_usStockIsEtc() {
        let sut = PortfolioWeightUseCase()
        let slices = sut.weights(accounts: accounts(), dimension: .exchange, usdToKrw: 1300)
        assertPercentSums100(slices)
        XCTAssertNotNil(slices.first { $0.label == "기타" })   // US stock
        XCTAssertNotNil(slices.first { $0.label == "KRX" })
        XCTAssertNotNil(slices.first { $0.label == "업비트" })
    }

    func test_empty_returnsEmpty() {
        let sut = PortfolioWeightUseCase()
        XCTAssertTrue(sut.weights(accounts: [], dimension: .holding, usdToKrw: 1300).isEmpty)
    }
}
