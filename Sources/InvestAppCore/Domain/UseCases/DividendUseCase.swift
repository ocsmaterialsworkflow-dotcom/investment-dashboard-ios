import Foundation

/// 배당 분석 순수 유스케이스.
///
/// 모든 집계는 `paymentDate`(지급일) 의 연도를 기준으로 필터링하며,
/// 금액은 `DividendSchedule.totalAmount`(KRW) 를 사용한다.
public struct DividendUseCase: Sendable {

    private let calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    /// 지정 연도의 연간 총 배당금 (KRW).
    /// - Parameters:
    ///   - schedules: 배당 일정 목록.
    ///   - year: 대상 연도 (지급일 기준).
    ///   - usdToKrw: USD→KRW 환율 (현재는 totalAmount 가 이미 KRW 라 사용하지 않으나
    ///     향후 amountPerShare 기반 환산 확장을 위해 시그니처에 유지).
    public func annualTotal(_ schedules: [DividendSchedule], year: Int, usdToKrw: Double) -> Double {
        schedules
            .filter { calendar.component(.year, from: $0.paymentDate) == year }
            .reduce(0) { $0 + $1.totalAmount }
    }

    /// 지정 연도의 월별 총 배당금 (KRW). 키는 1...12, 배당이 없는 달은 0.
    public func monthlyTotals(_ schedules: [DividendSchedule], year: Int, usdToKrw: Double) -> [Int: Double] {
        var totals: [Int: Double] = [:]
        for month in 1...12 { totals[month] = 0 }

        for schedule in schedules where calendar.component(.year, from: schedule.paymentDate) == year {
            let month = calendar.component(.month, from: schedule.paymentDate)
            totals[month, default: 0] += schedule.totalAmount
        }
        return totals
    }

    /// 배당수익률(%). 연간 배당(KRW) / 투자원금(KRW) * 100. 원금이 0이면 0.
    public func dividendYield(annualKRW: Double, investedKRW: Double) -> Double {
        guard investedKRW != 0 else { return 0 }
        return annualKRW / investedKRW * 100
    }
}
