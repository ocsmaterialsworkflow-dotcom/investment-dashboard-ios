import Foundation

// `HoldingProfit` 는 Presentation/AnalysisViewModel.swift 에 정의되어 있어 여기서 재정의하지 않는다.
// (필드: id, symbol, name, profitKRW, profitRate)

/// 기간별 손익 요약.
public struct ProfitSummary: Sendable {
    /// 총 손익 (KRW).
    public let totalProfitLoss: Double
    /// 총 수익률(%).
    public let profitLossRate: Double
    /// 종목별 손익 (손익 금액 내림차순 정렬).
    public let breakdown: [HoldingProfit]

    public init(totalProfitLoss: Double, profitLossRate: Double, breakdown: [HoldingProfit]) {
        self.totalProfitLoss = totalProfitLoss
        self.profitLossRate = profitLossRate
        self.breakdown = breakdown
    }
}

/// 기간 기반 손익 분석 순수 유스케이스.
///
/// - `.today` / `.total` 은 보유 종목의 평가손익을 그대로 집계한다.
/// - `.week` / `.month` / `.quarter` / `.year` 는 스냅샷 델타(기간 시작 ~ 종료의 손익 변화)로
///   계산하며, 스냅샷이 없으면 보유 종목 평가손익으로 폴백한다.
public struct ProfitAnalysisUseCase: Sendable {

    public init() {}

    public func execute(
        holdings: [Holding],
        snapshots: [AssetSnapshot],
        period: AnalysisPeriod,
        usdToKrw: Double,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProfitSummary {
        let breakdown = makeBreakdown(holdings: holdings, usdToKrw: usdToKrw)

        switch period {
        case .today, .total:
            let total = breakdown.reduce(0) { $0 + $1.profitKRW }
            let basis = costBasisKRW(holdings, usdToKrw: usdToKrw)
            let rate = basis != 0 ? total / basis * 100 : 0
            return ProfitSummary(totalProfitLoss: total, profitLossRate: rate, breakdown: breakdown)

        case .week, .month, .quarter, .year:
            if let delta = snapshotDelta(snapshots, period: period, now: now, calendar: calendar) {
                return ProfitSummary(
                    totalProfitLoss: delta.amount,
                    profitLossRate: delta.rate,
                    breakdown: breakdown
                )
            }
            // 폴백: 보유 종목 평가손익.
            let total = breakdown.reduce(0) { $0 + $1.profitKRW }
            let basis = costBasisKRW(holdings, usdToKrw: usdToKrw)
            let rate = basis != 0 ? total / basis * 100 : 0
            return ProfitSummary(totalProfitLoss: total, profitLossRate: rate, breakdown: breakdown)
        }
    }

    // MARK: - Helpers

    private func makeBreakdown(holdings: [Holding], usdToKrw: Double) -> [HoldingProfit] {
        holdings
            .map { h in
                let pl: Double = (h.currency == .usd) ? h.profitLoss * usdToKrw : h.profitLoss
                return HoldingProfit(
                    id: h.id,
                    symbol: h.symbol,
                    name: h.name,
                    profitKRW: pl,
                    profitRate: h.profitLossRate
                )
            }
            .sorted { $0.profitKRW > $1.profitKRW }
    }

    private func costBasisKRW(_ holdings: [Holding], usdToKrw: Double) -> Double {
        holdings.reduce(0) { acc, h in
            acc + ((h.currency == .usd) ? h.costBasis * usdToKrw : h.costBasis)
        }
    }

    /// 기간 시작점 이후 첫 스냅샷과 마지막 스냅샷의 손익(profit) 차이.
    private func snapshotDelta(
        _ snapshots: [AssetSnapshot],
        period: AnalysisPeriod,
        now: Date,
        calendar: Calendar
    ) -> (amount: Double, rate: Double)? {
        guard !snapshots.isEmpty, let range = period.dateRange(now: now, calendar: calendar) else {
            return nil
        }
        let inRange = snapshots
            .filter { $0.date >= range.start && $0.date <= range.end }
            .sorted { $0.date < $1.date }
        guard let first = inRange.first, let last = inRange.last else { return nil }

        let amount = last.profit - first.profit
        // 수익률: 기간 시작 원금 기준 변화율. 시작 원금이 0이면 0.
        let rate = first.principal != 0 ? amount / first.principal * 100 : 0
        return (amount, rate)
    }
}
