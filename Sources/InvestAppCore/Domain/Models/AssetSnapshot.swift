import Foundation

/// 특정 시점의 자산 스냅샷.
///
/// 추이/기간별 수익 분석의 기반 데이터. 모든 금액은 KRW 기준.
public struct AssetSnapshot: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let date: Date
    public let totalValue: Double   // 총 평가금액 (KRW)
    public let principal: Double    // 원금 (KRW)

    public init(
        id: UUID = UUID(),
        date: Date,
        totalValue: Double,
        principal: Double
    ) {
        self.id = id
        self.date = date
        self.totalValue = totalValue
        self.principal = principal
    }

    /// 평가손익 (KRW). 평가금액 - 원금.
    public var profit: Double { totalValue - principal }

    /// 수익률(%). 원금이 0이면 0.
    public var profitRate: Double {
        guard principal != 0 else { return 0 }
        return profit / principal * 100
    }
}
