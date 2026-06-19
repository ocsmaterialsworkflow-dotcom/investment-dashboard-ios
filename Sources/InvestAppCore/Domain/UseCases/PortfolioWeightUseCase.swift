import Foundation

// `WeightDimension`, `WeightSlice` 는 Presentation/PortfolioViewModel.swift 에 정의되어 있어
// 여기서 재정의하지 않고 그대로 사용한다.

/// 포트폴리오 비중 계산 순수 유스케이스.
public struct PortfolioWeightUseCase: Sendable {

    public init() {}

    /// 분류 기준별 비중 조각. 비중(percent) 내림차순 정렬.
    /// percent 합계는 (값이 있을 경우) 약 100 이 된다.
    public func weights(
        accounts: [Account],
        dimension: WeightDimension,
        usdToKrw: Double
    ) -> [WeightSlice] {
        // (key, label, value) 누적
        var values: [String: Double] = [:]
        var labels: [String: String] = [:]
        // 안정적 정렬을 위해 첫 등장 순서 기록
        var order: [String] = []

        func add(key: String, label: String, value: Double) {
            if values[key] == nil {
                order.append(key)
                labels[key] = label
            }
            values[key, default: 0] += value
        }

        for account in accounts {
            switch dimension {
            case .account:
                let v = account.totalValueKRW(usdToKrw: usdToKrw)
                add(key: account.id.uuidString, label: account.name, value: v)

            default:
                for holding in account.holdings {
                    let v = holding.evaluatedValueKRW(usdToKrw: usdToKrw)
                    let (key, label) = classify(holding: holding, account: account, dimension: dimension)
                    add(key: key, label: label, value: v)
                }
            }
        }

        let total = values.values.reduce(0, +)
        let slices = order.map { key -> WeightSlice in
            let value = values[key] ?? 0
            let percent = total != 0 ? value / total * 100 : 0
            return WeightSlice(label: labels[key] ?? key, valueKRW: value, percent: percent)
        }
        return slices.sorted { $0.percent > $1.percent }
    }

    // MARK: - Classification

    private func classify(
        holding: Holding,
        account: Account,
        dimension: WeightDimension
    ) -> (key: String, label: String) {
        switch dimension {
        case .holding:
            return (holding.id.uuidString, holding.name)

        case .type:
            switch holding.market {
            case .crypto:
                return ("crypto", "코인")
            case .usStock, .krStock:
                return ("stock", "주식")
            }

        case .country:
            switch holding.market {
            case .usStock:
                return ("us", "미국")
            case .krStock:
                return ("kr", "한국")
            case .crypto:
                return ("crypto", "코인")
            }

        case .exchange:
            return exchange(for: holding)

        case .account:
            // 위에서 처리되므로 도달하지 않음.
            return (account.id.uuidString, account.name)
        }
    }

    /// 거래소 매핑 (플레이스홀더). 시장 기준 추정, 미상이면 "기타".
    private func exchange(for holding: Holding) -> (key: String, label: String) {
        switch holding.market {
        case .crypto:
            return ("upbit", "업비트")
        case .krStock:
            return ("krx", "KRX")
        case .usStock:
            // NYSE/NASDAQ 구분 정보가 없으므로 기타로 분류.
            return ("etc", "기타")
        }
    }
}
