import XCTest
@testable import InvestAppCore

final class ProfitAnalysisTests: XCTestCase {

    private func date(_ days: Int, from base: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> Date {
        base.addingTimeInterval(Double(days) * 86_400)
    }

    // KRW 종목: 평단 100, 현재 120, 수량 10 → 손익 200
    private func krHolding() -> Holding {
        Holding(symbol: "005930", name: "삼성전자", market: .krStock,
                quantity: 10, averageCost: 100, currentPrice: 120, currency: .krw)
    }

    // USD 종목: 평단 10, 현재 15, 수량 2 → 손익 10 USD → KRW 환산 (1300) 13000
    private func usHolding() -> Holding {
        Holding(symbol: "AAPL", name: "Apple", market: .usStock,
                quantity: 2, averageCost: 10, currentPrice: 15, currency: .usd)
    }

    func test_today_sumsHoldingProfit_mixedCurrencies() {
        let sut = ProfitAnalysisUseCase()
        let summary = sut.execute(
            holdings: [krHolding(), usHolding()],
            snapshots: [],
            period: .today,
            usdToKrw: 1300
        )
        // 200 (KRW) + 13000 (USD환산) = 13200
        XCTAssertEqual(summary.totalProfitLoss, 13_200, accuracy: 0.001)
        XCTAssertEqual(summary.breakdown.count, 2)
        // 내림차순 정렬: AAPL(13000) 먼저
        XCTAssertEqual(summary.breakdown.first?.symbol, "AAPL")
        XCTAssertEqual(summary.breakdown.first?.profitKRW, 13_000, accuracy: 0.001)
    }

    func test_total_computesRate_fromCostBasis() {
        let sut = ProfitAnalysisUseCase()
        // KRW only: costBasis = 1000, profit = 200 → 20%
        let summary = sut.execute(
            holdings: [krHolding()],
            snapshots: [],
            period: .total,
            usdToKrw: 1300
        )
        XCTAssertEqual(summary.totalProfitLoss, 200, accuracy: 0.001)
        XCTAssertEqual(summary.profitLossRate, 20, accuracy: 0.001)
    }

    func test_empty_returnsZero() {
        let sut = ProfitAnalysisUseCase()
        let summary = sut.execute(holdings: [], snapshots: [], period: .total, usdToKrw: 1300)
        XCTAssertEqual(summary.totalProfitLoss, 0)
        XCTAssertEqual(summary.profitLossRate, 0)
        XCTAssertTrue(summary.breakdown.isEmpty)
    }

    func test_month_usesSnapshotDelta() {
        let sut = ProfitAnalysisUseCase()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        // 한 달 범위 내 스냅샷: profit 시작 100 → 끝 500, 델타 400.
        let snaps = [
            AssetSnapshot(date: now.addingTimeInterval(-20 * 86_400), totalValue: 1_100, principal: 1_000),
            AssetSnapshot(date: now.addingTimeInterval(-1 * 86_400), totalValue: 1_500, principal: 1_000)
        ]
        let summary = sut.execute(
            holdings: [krHolding()],
            snapshots: snaps,
            period: .month,
            usdToKrw: 1300,
            now: now
        )
        XCTAssertEqual(summary.totalProfitLoss, 400, accuracy: 0.001)  // 500 - 100
        XCTAssertEqual(summary.profitLossRate, 40, accuracy: 0.001)    // 400 / 1000
    }

    func test_month_withoutSnapshots_fallsBackToHoldingProfit() {
        let sut = ProfitAnalysisUseCase()
        let summary = sut.execute(
            holdings: [krHolding()],
            snapshots: [],
            period: .month,
            usdToKrw: 1300
        )
        XCTAssertEqual(summary.totalProfitLoss, 200, accuracy: 0.001)
    }
}
