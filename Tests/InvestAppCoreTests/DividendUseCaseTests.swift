import XCTest
@testable import InvestAppCore

final class DividendUseCaseTests: XCTestCase {

    private func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ iso: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: iso)!
    }

    private func schedule(symbol: String = "AAPL", pay: String, totalKRW: Double) -> DividendSchedule {
        DividendSchedule(
            symbol: symbol,
            exDividendDate: date(pay),
            paymentDate: date(pay),
            amountPerShare: 0.5,
            totalAmount: totalKRW,
            isConfirmed: true
        )
    }

    func test_annualTotal_filtersByPaymentYear() {
        let sut = DividendUseCase(calendar: cal())
        let schedules = [
            schedule(pay: "2025-03-10", totalKRW: 10_000),
            schedule(pay: "2025-06-10", totalKRW: 12_000),
            schedule(pay: "2024-12-10", totalKRW: 99_000)  // 다른 연도
        ]
        XCTAssertEqual(sut.annualTotal(schedules, year: 2025, usdToKrw: 1300), 22_000, accuracy: 0.001)
        XCTAssertEqual(sut.annualTotal(schedules, year: 2024, usdToKrw: 1300), 99_000, accuracy: 0.001)
        XCTAssertEqual(sut.annualTotal(schedules, year: 2023, usdToKrw: 1300), 0)
    }

    func test_monthlyTotals_hasAllTwelveMonths_andSums() {
        let sut = DividendUseCase(calendar: cal())
        let schedules = [
            schedule(pay: "2025-03-10", totalKRW: 10_000),
            schedule(pay: "2025-03-25", totalKRW: 5_000),
            schedule(pay: "2025-09-10", totalKRW: 7_000)
        ]
        let monthly = sut.monthlyTotals(schedules, year: 2025, usdToKrw: 1300)
        XCTAssertEqual(monthly.count, 12)
        XCTAssertEqual(monthly[3] ?? 0, 15_000, accuracy: 0.001)
        XCTAssertEqual(monthly[9] ?? 0, 7_000, accuracy: 0.001)
        XCTAssertEqual(monthly[1], 0)
        // 합계 검증
        let sum = monthly.values.reduce(0, +)
        XCTAssertEqual(sum, 22_000, accuracy: 0.001)
    }

    func test_dividendYield() {
        let sut = DividendUseCase(calendar: cal())
        XCTAssertEqual(sut.dividendYield(annualKRW: 30_000, investedKRW: 1_000_000), 3.0, accuracy: 0.0001)
        XCTAssertEqual(sut.dividendYield(annualKRW: 30_000, investedKRW: 0), 0)
    }

    func test_empty_returnsZeroAndEmptyMonths() {
        let sut = DividendUseCase(calendar: cal())
        XCTAssertEqual(sut.annualTotal([], year: 2025, usdToKrw: 1300), 0)
        let monthly = sut.monthlyTotals([], year: 2025, usdToKrw: 1300)
        XCTAssertEqual(monthly.count, 12)
        XCTAssertEqual(monthly.values.reduce(0, +), 0)
    }
}
