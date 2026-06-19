import XCTest
@testable import InvestAppCore

final class AnalysisPeriodTests: XCTestCase {

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ iso: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: iso)!
    }

    func test_total_returnsNil() {
        XCTAssertNil(AnalysisPeriod.total.dateRange())
    }

    func test_today_startsAtMidnight() {
        let cal = utcCalendar()
        let now = date("2026-06-19T15:30:00")
        let range = AnalysisPeriod.today.dateRange(now: now, calendar: cal)
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, date("2026-06-19T00:00:00"))
        XCTAssertEqual(range?.end, now)
    }

    func test_week_isSevenDaysBack() {
        let cal = utcCalendar()
        let now = date("2026-06-19T12:00:00")
        let range = AnalysisPeriod.week.dateRange(now: now, calendar: cal)
        XCTAssertEqual(range?.start, date("2026-06-12T12:00:00"))
    }

    func test_month_quarter_year_offsets() {
        let cal = utcCalendar()
        let now = date("2026-06-19T12:00:00")
        XCTAssertEqual(AnalysisPeriod.month.dateRange(now: now, calendar: cal)?.start, date("2026-05-19T12:00:00"))
        XCTAssertEqual(AnalysisPeriod.quarter.dateRange(now: now, calendar: cal)?.start, date("2026-03-19T12:00:00"))
        XCTAssertEqual(AnalysisPeriod.year.dateRange(now: now, calendar: cal)?.start, date("2025-06-19T12:00:00"))
    }

    func test_allCases_haveDisplayName() {
        for p in AnalysisPeriod.allCases {
            XCTAssertFalse(p.displayName.isEmpty)
        }
        XCTAssertEqual(AnalysisPeriod.allCases.count, 6)
    }
}
