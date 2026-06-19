import Foundation

/// 전체 자산 집계 결과.
public struct TotalAssets: Sendable, Equatable {
    /// 총 평가금액 (KRW).
    public let totalValue: Double
    /// 총 매수원금 (KRW).
    public let principal: Double
    /// 누적 평가손익 (KRW). 평가금액 - 원금.
    public let totalProfitLoss: Double
    /// 누적 수익률(%). 원금이 0이면 0.
    public let totalProfitLossRate: Double
    /// 보유 종목 평가손익 합계 (KRW). (오늘 기준 손익으로 사용)
    public let todayProfitLoss: Double

    public init(
        totalValue: Double,
        principal: Double,
        totalProfitLoss: Double,
        totalProfitLossRate: Double,
        todayProfitLoss: Double
    ) {
        self.totalValue = totalValue
        self.principal = principal
        self.totalProfitLoss = totalProfitLoss
        self.totalProfitLossRate = totalProfitLossRate
        self.todayProfitLoss = todayProfitLoss
    }
}

/// 모든 계좌의 보유 종목을 환율로 KRW 환산해 총자산을 집계하는 순수 유스케이스.
public struct FetchTotalAssetsUseCase: Sendable {

    public init() {}

    /// - Parameters:
    ///   - accounts: 집계 대상 계좌 목록.
    ///   - usdToKrw: USD→KRW 환율.
    /// - Returns: KRW 기준 총자산 집계.
    public func execute(accounts: [Account], usdToKrw: Double) -> TotalAssets {
        let holdings = accounts.flatMap { $0.holdings }

        let totalValue = holdings.reduce(0) { $0 + $1.evaluatedValueKRW(usdToKrw: usdToKrw) }
        let principal = holdings.reduce(0) { $0 + krwCostBasis($1, usdToKrw: usdToKrw) }
        let profitLoss = totalValue - principal
        let rate = principal != 0 ? profitLoss / principal * 100 : 0

        // 오늘 손익: 보유 종목별 평가손익(KRW 환산) 합계.
        let today = holdings.reduce(0) { $0 + krwProfitLoss($1, usdToKrw: usdToKrw) }

        return TotalAssets(
            totalValue: totalValue,
            principal: principal,
            totalProfitLoss: profitLoss,
            totalProfitLossRate: rate,
            todayProfitLoss: today
        )
    }

    private func krwCostBasis(_ holding: Holding, usdToKrw: Double) -> Double {
        switch holding.currency {
        case .krw: return holding.costBasis
        case .usd: return holding.costBasis * usdToKrw
        }
    }

    private func krwProfitLoss(_ holding: Holding, usdToKrw: Double) -> Double {
        switch holding.currency {
        case .krw: return holding.profitLoss
        case .usd: return holding.profitLoss * usdToKrw
        }
    }
}
