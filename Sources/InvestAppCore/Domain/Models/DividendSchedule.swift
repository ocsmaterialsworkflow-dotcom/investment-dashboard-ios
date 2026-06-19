import Foundation

/// 배당 일정 1건.
///
/// `amountPerShare` 는 원 통화(USD) 기준 1주당 배당금이며,
/// `totalAmount` 는 보유 수량을 곱해 KRW 로 환산한 총 배당금이다.
/// 시세 연동 시점에는 `totalAmount` 를 0 으로 두고, 보유 수량/환율을 아는 곳에서 채운다.
public struct DividendSchedule: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let symbol: String           // "AAPL"
    public let exDividendDate: Date     // 배당락일
    public let paymentDate: Date        // 지급일
    public let amountPerShare: Double    // 1주당 배당금 (USD)
    public let totalAmount: Double       // 총 배당금 (KRW)
    public let isConfirmed: Bool         // 확정 여부 (예정 vs 확정)

    public init(
        id: UUID = UUID(),
        symbol: String,
        exDividendDate: Date,
        paymentDate: Date,
        amountPerShare: Double,
        totalAmount: Double,
        isConfirmed: Bool
    ) {
        self.id = id
        self.symbol = symbol
        self.exDividendDate = exDividendDate
        self.paymentDate = paymentDate
        self.amountPerShare = amountPerShare
        self.totalAmount = totalAmount
        self.isConfirmed = isConfirmed
    }
}
