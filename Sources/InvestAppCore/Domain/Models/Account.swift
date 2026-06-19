import Foundation

public enum AccountType: String, Codable, Sendable {
    case general    // 일반 위탁
    case cma
    case isa
    case ria        // 일임/RIA
    case cryptoWallet
}

/// 한 계좌(거래소/증권사 계정)와 그 보유 종목.
public struct Account: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let broker: Broker
    public let accountType: AccountType
    public let name: String
    public var holdings: [Holding]

    public init(
        id: UUID = UUID(),
        broker: Broker,
        accountType: AccountType,
        name: String,
        holdings: [Holding] = []
    ) {
        self.id = id
        self.broker = broker
        self.accountType = accountType
        self.name = name
        self.holdings = holdings
    }

    /// 지정 환율 기준 계좌 총 평가금액(KRW).
    public func totalValueKRW(usdToKrw: Double) -> Double {
        holdings.reduce(0) { $0 + $1.evaluatedValueKRW(usdToKrw: usdToKrw) }
    }
}
