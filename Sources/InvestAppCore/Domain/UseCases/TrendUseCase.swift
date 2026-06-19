import Foundation

/// 자산 추이 분석 순수 유스케이스.
public struct TrendUseCase: Sendable {

    public init() {}

    /// 기간으로 필터링하고 날짜 오름차순 정렬한 스냅샷 시계열.
    ///
    /// - `.total` 은 전체 스냅샷을 정렬만 해 반환한다.
    /// - 그 외 기간은 `dateRange` 범위 내 스냅샷만 반환한다.
    public func series(
        _ snapshots: [AssetSnapshot],
        period: AnalysisPeriod,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [AssetSnapshot] {
        let sorted = snapshots.sorted { $0.date < $1.date }
        guard let range = period.dateRange(now: now, calendar: calendar) else {
            return sorted  // .total
        }
        return sorted.filter { $0.date >= range.start && $0.date <= range.end }
    }

    /// 지정 날짜의 자산 평가금액(KRW).
    ///
    /// 같은 날(달력상 동일 일자)의 스냅샷이 있으면 그 값을, 없으면 해당 날짜 이하의
    /// 가장 최근 스냅샷 값을 반환한다. 해당 날짜 이전 스냅샷이 전혀 없으면 `nil`.
    public func valueAt(
        date: Date,
        in snapshots: [AssetSnapshot],
        calendar: Calendar = .current
    ) -> Double? {
        if let exact = snapshots.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return exact.totalValue
        }
        return snapshots
            .filter { $0.date <= date }
            .max(by: { $0.date < $1.date })?
            .totalValue
    }
}
