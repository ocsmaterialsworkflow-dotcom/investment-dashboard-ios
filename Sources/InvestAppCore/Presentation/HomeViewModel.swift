import Foundation
import Observation

// MARK: - Thin Protocol Abstractions

/// 총자산 계산에 필요한 현재 환율 값만 제공하는 얇은 프로토콜.
///
/// `ExchangeRateManager` 가 채택하도록 오케스트레이터가 연결한다.
/// (기존 `ExchangeRateProviding` 은 비동기 fetch 용이므로 별도 이름 사용)
public protocol CurrentRateProviding: AnyObject, Sendable {
    /// 현재 USD→KRW 환율.
    var usdToKrw: Double { get }
}

// MARK: - Sort Mode

/// 보유 종목 정렬 방식.
public enum HoldingSortMode: String, CaseIterable, Sendable {
    /// 총수익(손익 KRW) 내림차순.
    case profitAmount = "총수익"
    /// 수익률(%) 내림차순.
    case profitRate   = "수익률"
    /// 직접설정 (API 응답 순서 유지).
    case manual       = "직접설정"

    /// 화면 표시용 이름.
    public var displayName: String { rawValue }
}

// MARK: - Valuation Mode

/// 평가금액 표시 방식.
public enum ValuationMode: String, CaseIterable, Sendable {
    /// 현재 시세 기준 평가금액.
    case market  = "시세"
    /// 평가(매입 포함) 기준.
    case book    = "평가"

    /// 화면 표시용 이름.
    public var displayName: String { rawValue }
}

// MARK: - HomeViewModel

/// 홈 탭 ViewModel.
///
/// - 복수의 `BrokerAccountProviding` 에서 병렬로 계좌를 로드한다.
/// - 한 곳에서 에러가 발생해도 나머지 결과를 유지한다 (부분 실패 허용).
/// - ViewModels 은 SwiftUI 를 import 하지 않으므로 패키지 내 단위 테스트가 가능하다.
@MainActor
@Observable
public final class HomeViewModel {

    // MARK: - Published State

    /// 모든 계좌의 총 평가금액 (KRW).
    public var totalAssetsKRW: Double = 0

    /// 오늘 손익 (KRW). 스냅샷이 없으면 0.
    public var todayProfit: Double = 0

    /// 오늘 수익률 (%). 원금이 0이면 0.
    public var todayProfitRate: Double = 0

    /// 정렬 후 평탄화된 보유 종목 목록.
    public var holdings: [Holding] = []

    /// 평가금액 표시 방식 (시세 / 평가).
    public var valuationMode: ValuationMode = .market

    /// 정렬 방식.
    public var sortMode: HoldingSortMode = .profitAmount

    /// 로딩 중 여부.
    public var isLoading: Bool = false

    /// 에러 메시지. 전체 실패일 때만 set. 부분 실패는 무시.
    public var error: String?

    // MARK: - Internal State

    private var accounts: [Account] = []

    // MARK: - Dependencies

    private let providers: [BrokerAccountProviding]
    private let exchangeRateProvider: CurrentRateProviding

    // MARK: - Init

    /// - Parameters:
    ///   - providers: 브로커별 계좌 제공자 배열.
    ///   - exchangeRateProvider: 현재 환율을 제공하는 객체 (ExchangeRateManager 주입).
    public init(
        providers: [BrokerAccountProviding],
        exchangeRateProvider: CurrentRateProviding
    ) {
        self.providers = providers
        self.exchangeRateProvider = exchangeRateProvider
    }

    // MARK: - Public Methods

    /// 모든 계좌를 병렬 로드하고 총자산·보유종목을 갱신한다.
    ///
    /// 한 provider 가 throw 해도 나머지 결과는 반영한다.
    public func refresh() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // 병렬 페치: 각 provider 의 결과를 (Result) 로 감싸 수집
        let results: [Result<Account, Error>] = await withTaskGroup(
            of: Result<Account, Error>.self
        ) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let account = try await provider.fetchAccount()
                        return .success(account)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var collected: [Result<Account, Error>] = []
            for await result in group { collected.append(result) }
            return collected
        }

        // 성공한 계좌만 반영
        let loaded = results.compactMap { result -> Account? in
            if case .success(let account) = result { return account }
            return nil
        }

        accounts = loaded

        if loaded.isEmpty && !providers.isEmpty {
            let firstError = results.compactMap { result -> Error? in
                if case .failure(let e) = result { return e }
                return nil
            }.first
            error = firstError?.localizedDescription ?? "계좌를 불러오지 못했습니다."
        }

        recomputeMetrics()
        recomputeHoldings()
    }

    /// 정렬 방식을 변경하고 보유 종목 목록을 재정렬한다.
    public func setSortMode(_ mode: HoldingSortMode) {
        sortMode = mode
        recomputeHoldings()
    }

    /// 평가금액 표시 방식을 토글한다.
    public func toggleValuationMode() {
        valuationMode = valuationMode == .market ? .book : .market
    }

    // MARK: - Private Helpers

    private func recomputeMetrics() {
        let rate = exchangeRateProvider.usdToKrw
        totalAssetsKRW = accounts.reduce(0) { $0 + $1.totalValueKRW(usdToKrw: rate) }

        // 오늘 손익: 총 평가손익의 합 (실제 스냅샷 기반 계산은 UseCase 레이어에서)
        let totalProfitLoss = accounts.flatMap(\.holdings).reduce(0.0) { sum, h in
            sum + (h.currency == .usd
                ? h.profitLoss * rate
                : h.profitLoss)
        }
        todayProfit = totalProfitLoss

        let totalCost = accounts.flatMap(\.holdings).reduce(0.0) { sum, h in
            sum + (h.currency == .usd
                ? h.costBasis * rate
                : h.costBasis)
        }
        todayProfitRate = totalCost != 0 ? totalProfitLoss / totalCost * 100 : 0
    }

    private func recomputeHoldings() {
        let rate = exchangeRateProvider.usdToKrw
        let flat = accounts.flatMap(\.holdings)

        switch sortMode {
        case .profitAmount:
            holdings = flat.sorted {
                let lhs = $0.currency == .usd ? $0.profitLoss * rate : $0.profitLoss
                let rhs = $1.currency == .usd ? $1.profitLoss * rate : $1.profitLoss
                return lhs > rhs
            }
        case .profitRate:
            holdings = flat.sorted { $0.profitLossRate > $1.profitLossRate }
        case .manual:
            holdings = flat
        }
    }
}
