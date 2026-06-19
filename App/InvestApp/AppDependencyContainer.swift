import Foundation
import InvestAppCore

/// 앱 DI 컨테이너.
///
/// 보유한 자격증명(Keychain)에 따라 브로커 저장소를 동적으로 구성하고,
/// 순수 UseCase 를 ViewModel 이 기대하는 얇은 프로토콜로 어댑터를 통해 연결한다.
///
/// - 코어 로직(`InvestAppCore`)은 CI(`swift test`)에서 검증된다.
/// - 이 파일은 SwiftUI 앱 타깃 전용이며 Xcode 에서 컴파일된다.
@MainActor
public final class AppDependencyContainer {

    // MARK: - Shared Infrastructure

    public let keychainStore: SecretStore = KeychainManager()
    private let http: HTTPClient = URLSessionHTTPClient()

    /// KIS 계좌번호(종합계좌-상품코드). 설정에서 입력받아 주입한다. 예: "12345678-01"
    public var kisAccountNo: String?
    /// Finnhub 배당/시세 조회를 위한 미국주식 심볼 목록(보유 종목에서 채운다).
    public var usSymbols: [String] = []

    // MARK: - Exchange Rate

    public lazy var exchangeRateManager: ExchangeRateManager = {
        let bokKey = (try? keychainStore.load(for: .bokApiKey)) ?? ""
        let provider = ExchangeRateRepository(
            primary: BOKExchangeRateClient(http: http, apiKey: bokKey),
            fallback: FallbackExchangeRateClient(http: http)
        )
        return ExchangeRateManager(provider: provider)
    }()

    // MARK: - Broker Providers (보유 자격증명에 따라 동적 구성)

    public var brokerProviders: [BrokerAccountProviding] {
        var list: [BrokerAccountProviding] = []

        // 업비트 — Access/Secret Key 보유 시
        if keychainStore.contains(.upbitAccessKey), keychainStore.contains(.upbitSecretKey) {
            let client = UpbitAPIClient(http: http, secrets: keychainStore)
            list.append(UpbitRepository(client: client))
        }

        // 토스증권 — Client ID/Secret 보유 시
        if keychainStore.contains(.tossClientId), keychainStore.contains(.tossClientSecret),
           let toss = try? TossAPIClient(http: http, secrets: keychainStore) {
            list.append(TossRepository(client: toss))
        }

        // 한국투자증권(KIS) — 키 + 계좌번호 보유 시
        if keychainStore.contains(.kisAppKey), keychainStore.contains(.kisAppSecret),
           let accountNo = kisAccountNo,
           let kis = try? KISAPIClient(http: http, secrets: keychainStore, accountNo: accountNo) {
            list.append(KISRepository(client: kis))
        }

        // NH투자증권 — iOS 직접연동 불가(placeholder). 브릿지 백엔드 마련 시 활성화.
        // list.append(NHBridgeAccountProvider(bridgeBaseURL: ...))

        return list
    }

    /// MainActor 격리된 환율 값을 어댑터에 안전하게 전달하기 위한 클로저.
    private func currentRate() -> Double {
        exchangeRateManager.usdToKrw
    }

    // MARK: - ViewModels

    public lazy var homeViewModel: HomeViewModel = HomeViewModel(
        providers: brokerProviders,
        exchangeRateProvider: ExchangeRateManagerAdapter(manager: exchangeRateManager)
    )

    public lazy var analysisViewModel: AnalysisViewModel = AnalysisViewModel(
        useCase: ProfitAnalysisAdapter(providers: brokerProviders, rate: rateSnapshot())
    )

    public lazy var portfolioViewModel: PortfolioViewModel = PortfolioViewModel(
        useCase: PortfolioWeightAdapter(providers: brokerProviders, rate: rateSnapshot())
    )

    public lazy var dividendViewModel: DividendViewModel = DividendViewModel(
        useCase: DividendAdapter(
            providers: brokerProviders,
            rate: rateSnapshot(),
            market: finnhubClient
        )
    )

    public lazy var trendViewModel: TrendViewModel = TrendViewModel(
        // TODO: SwiftData 일별 스냅샷 스토어 연결 (현재는 빈 시계열).
        useCase: TrendAdapter(snapshotStore: { [] })
    )

    public lazy var settingsViewModel: SettingsViewModel = SettingsViewModel(store: keychainStore)

    // MARK: - Finnhub (미국주식 시세·배당)

    private var finnhubClient: MarketDataProviding? {
        guard let key = try? keychainStore.load(for: .finnhubApiKey), !key.isEmpty else { return nil }
        return FinnhubClient(http: http, apiKey: key)
    }

    /// 환율 스냅샷 클로저. ViewModel(@MainActor)에서 호출되므로 MainActor 컨텍스트에서 평가된다.
    private func rateSnapshot() -> @Sendable () -> Double {
        let manager = exchangeRateManager
        return { MainActor.assumeIsolated { manager.usdToKrw } }
    }

    public init(kisAccountNo: String? = nil) {
        self.kisAccountNo = kisAccountNo
    }
}

// MARK: - ExchangeRateManager Adapter

/// `ExchangeRateManager`(@Observable @MainActor)를 `CurrentRateProviding` 으로 감싼다.
private final class ExchangeRateManagerAdapter: CurrentRateProviding, @unchecked Sendable {
    private let manager: ExchangeRateManager
    init(manager: ExchangeRateManager) { self.manager = manager }
    var usdToKrw: Double { MainActor.assumeIsolated { manager.usdToKrw } }
}

// MARK: - UseCase Adapters (순수 UseCase → ViewModel 얇은 프로토콜)

/// 여러 브로커에서 계좌를 부분 실패 허용으로 병렬 로드한다.
private func loadAccounts(_ providers: [BrokerAccountProviding]) async -> [Account] {
    await withTaskGroup(of: Account?.self) { group in
        for provider in providers {
            group.addTask { try? await provider.fetchAccount() }
        }
        var result: [Account] = []
        for await account in group where account != nil {
            result.append(account!)
        }
        return result
    }
}

private struct ProfitAnalysisAdapter: ProfitAnalysisUseCaseProtocol {
    let providers: [BrokerAccountProviding]
    let rate: @Sendable () -> Double
    private let useCase = ProfitAnalysisUseCase()

    func execute(period: AnalysisPeriod) async throws -> ProfitAnalysisResult {
        let accounts = await loadAccounts(providers)
        let holdings = accounts.flatMap(\.holdings)
        // TODO: SwiftData 스냅샷 연결 시 기간별 델타 계산 정확도 향상.
        let summary = useCase.execute(holdings: holdings, snapshots: [], period: period, usdToKrw: rate())
        return ProfitAnalysisResult(
            period: period,
            profitKRW: summary.totalProfitLoss,
            profitRate: summary.profitLossRate,
            holdingProfits: summary.breakdown
        )
    }
}

private struct PortfolioWeightAdapter: PortfolioWeightUseCaseProtocol {
    let providers: [BrokerAccountProviding]
    let rate: @Sendable () -> Double
    private let useCase = PortfolioWeightUseCase()

    func execute(dimension: WeightDimension) async throws -> [WeightSlice] {
        let accounts = await loadAccounts(providers)
        return useCase.weights(accounts: accounts, dimension: dimension, usdToKrw: rate())
    }
}

private struct DividendAdapter: DividendUseCaseProtocol {
    let providers: [BrokerAccountProviding]
    let rate: @Sendable () -> Double
    let market: MarketDataProviding?

    func fetchSchedules(year: Int) async throws -> [DividendSchedule] {
        guard let market else { return [] }
        let accounts = await loadAccounts(providers)
        let usHoldings = accounts.flatMap(\.holdings).filter { $0.market == .usStock }
        let calendar = Calendar(identifier: .gregorian)
        let from = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let to = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()

        var schedules: [DividendSchedule] = []
        for holding in usHoldings {
            let items = (try? await market.dividends(symbol: holding.symbol, from: from, to: to)) ?? []
            // 주당 배당금 × 보유수량 × 환율 → 총 수령 예상액(KRW)
            for item in items {
                schedules.append(DividendSchedule(
                    id: item.id,
                    symbol: item.symbol,
                    exDividendDate: item.exDividendDate,
                    paymentDate: item.paymentDate,
                    amountPerShare: item.amountPerShare,
                    totalAmount: item.amountPerShare * holding.quantity * rate(),
                    isConfirmed: item.isConfirmed
                ))
            }
        }
        return schedules
    }
}

private struct TrendAdapter: TrendUseCaseProtocol {
    let snapshotStore: @Sendable () -> [AssetSnapshot]
    private let useCase = TrendUseCase()

    func fetchSnapshots(period: AnalysisPeriod) async throws -> [AssetSnapshot] {
        useCase.series(snapshotStore(), period: period)
    }
}
