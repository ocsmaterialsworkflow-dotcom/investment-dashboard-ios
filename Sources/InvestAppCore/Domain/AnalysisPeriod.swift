import Foundation

/// 분석 기간 단위.
///
/// `.total` 은 전체 기간을 의미하며 `dateRange` 가 `nil` 을 반환한다.
public enum AnalysisPeriod: String, CaseIterable, Sendable {
    case today
    case total
    case week
    case month
    case quarter
    case year

    /// 화면 표시용 한글 이름.
    public var displayName: String {
        switch self {
        case .today:   return "오늘"
        case .total:   return "전체"
        case .week:    return "1주일"
        case .month:   return "1개월"
        case .quarter: return "3개월"
        case .year:    return "1년"
        }
    }

    /// 기간의 시작/종료 시각.
    ///
    /// - `.total` 은 전체 기간이므로 `nil` 을 반환한다.
    /// - `.today` 는 오늘 0시 ~ 현재.
    /// - 나머지는 (현재 - 기간) ~ 현재.
    /// - Parameters:
    ///   - now: 기준 현재 시각 (테스트 주입용).
    ///   - calendar: 사용할 캘린더.
    /// - Returns: (start, end) 튜플, 또는 전체 기간이면 `nil`.
    public func dateRange(now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date)? {
        switch self {
        case .total:
            return nil
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (start, now)
        case .quarter:
            let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (start, now)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (start, now)
        }
    }
}
