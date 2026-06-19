import XCTest
@testable import InvestAppCore

final class TrendUseCaseTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ offset: Int) -> Date {
        base.addingTimeInterval(Double(offset) * 86_400)
    }

    private func snap(_ offset: Int, value: Double) -> AssetSnapshot {
        AssetSnapshot(date: day(offset), totalValue: value, principal: 1_000)
    }

    func test_series_total_returnsAllSortedByDate() {
        let sut = TrendUseCase()
        let snaps = [snap(2, value: 300), snap(0, value: 100), snap(1, value: 200)]
        let result = sut.series(snaps, period: .total)
        XCTAssertEqual(result.map { $0.totalValue }, [100, 200, 300])
    }

    func test_series_month_filtersByRange() {
        let sut = TrendUseCase()
        let now = day(0)
        // -40일(범위 밖), -10일(범위 안), -1일(범위 안)
        let snaps = [snap(-40, value: 50), snap(-10, value: 200), snap(-1, value: 300)]
        let result = sut.series(snaps, period: .month, now: now)
        XCTAssertEqual(result.map { $0.totalValue }, [200, 300])
    }

    func test_series_empty() {
        let sut = TrendUseCase()
        XCTAssertTrue(sut.series([], period: .total).isEmpty)
        XCTAssertTrue(sut.series([], period: .week, now: day(0)).isEmpty)
    }

    func test_valueAt_exactDay() {
        let sut = TrendUseCase()
        let snaps = [snap(0, value: 100), snap(2, value: 300)]
        XCTAssertEqual(sut.valueAt(date: day(0), in: snaps), 100)
    }

    func test_valueAt_fallsBackToMostRecentBefore() {
        let sut = TrendUseCase()
        let snaps = [snap(0, value: 100), snap(5, value: 500)]
        // day(3): 같은 날 없음 → 가장 최근 이전(day 0) 값
        XCTAssertEqual(sut.valueAt(date: day(3), in: snaps), 100)
    }

    func test_valueAt_noPriorSnapshot_returnsNil() {
        let sut = TrendUseCase()
        let snaps = [snap(5, value: 500)]
        XCTAssertNil(sut.valueAt(date: day(0), in: snaps))
    }
}
