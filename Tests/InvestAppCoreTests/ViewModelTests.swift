import XCTest
@testable import InvestAppCore

// MARK: - Test Helpers

/// 인메모리 환율 제공자 (테스트용).
private final class MockExchangeRateProvider: CurrentRateProviding, @unchecked Sendable {
    var usdToKrw: Double

    init(usdToKrw: Double = 1300) {
        self.usdToKrw = usdToKrw
    }
}

/// 성공하는 브로커 계좌 제공자 (테스트용).
private struct MockBrokerProvider: BrokerAccountProviding, Sendable {
    let broker: Broker
    let account: Account

    func fetchAccount() async throws -> Account { account }
}

/// 항상 에러를 던지는 브로커 계좌 제공자 (테스트용).
private struct FailingBrokerProvider: BrokerAccountProviding, Sendable {
    let broker: Broker

    func fetchAccount() async throws -> Account {
        throw URLError(.networkConnectionLost)
    }
}

/// 테스트용 손익 분석 UseCase.
private struct MockProfitAnalysisUseCase: ProfitAnalysisUseCaseProtocol, Sendable {
    let result: ProfitAnalysisResult

    func execute(period: AnalysisPeriod) async throws -> ProfitAnalysisResult { result }
}

/// 테스트용 배당 UseCase.
private struct MockDividendUseCase: DividendUseCaseProtocol, Sendable {
    let schedules: [DividendSchedule]

    func fetchSchedules(year: Int) async throws -> [DividendSchedule] { schedules }
}

/// 에러를 던지는 배당 UseCase.
private struct FailingDividendUseCase: DividendUseCaseProtocol, Sendable {
    func fetchSchedules(year: Int) async throws -> [DividendSchedule] {
        throw URLError(.badServerResponse)
    }
}

// MARK: - HomeViewModel Tests

@MainActor
final class HomeViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeKRWHolding(
        symbol: String = "BTC",
        quantity: Double = 1,
        averageCost: Double = 1_000_000,
        currentPrice: Double = 1_200_000
    ) -> Holding {
        Holding(
            symbol: symbol,
            name: symbol,
            market: .crypto,
            quantity: quantity,
            averageCost: averageCost,
            currentPrice: currentPrice,
            currency: .krw
        )
    }

    private func makeUSDHolding(
        symbol: String = "AAPL",
        quantity: Double = 10,
        averageCost: Double = 150,
        currentPrice: Double = 200
    ) -> Holding {
        Holding(
            symbol: symbol,
            name: symbol,
            market: .usStock,
            quantity: quantity,
            averageCost: averageCost,
            currentPrice: currentPrice,
            currency: .usd
        )
    }

    // MARK: - Tests

    func test_refresh_singleProvider_computesTotalAssets() async {
        // BTC 1개, 현재가 1,200,000원 → 총자산 1,200,000원
        let holding = makeKRWHolding()
        let account = Account(broker: .upbit, accountType: .cryptoWallet, name: "테스트",
                              holdings: [holding])
        let provider = MockBrokerProvider(broker: .upbit, account: account)
        let rateProvider = MockExchangeRateProvider(usdToKrw: 1300)

        let vm = HomeViewModel(providers: [provider], exchangeRateProvider: rateProvider)
        await vm.refresh()

        XCTAssertEqual(vm.totalAssetsKRW, 1_200_000, accuracy: 0.001)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    func test_refresh_mixedCurrencies_appliesExchangeRate() async {
        // KRW: BTC 1,000,000원
        // USD: AAPL 10주 @ $200 → $2000 * 1300 = 2,600,000원
        // 총계: 3,600,000원
        let krwHolding = makeKRWHolding(currentPrice: 1_000_000)
        let usdHolding = makeUSDHolding()
        let account = Account(broker: .upbit, accountType: .cryptoWallet, name: "테스트",
                              holdings: [krwHolding, usdHolding])
        let provider = MockBrokerProvider(broker: .upbit, account: account)
        let rateProvider = MockExchangeRateProvider(usdToKrw: 1300)

        let vm = HomeViewModel(providers: [provider], exchangeRateProvider: rateProvider)
        await vm.refresh()

        XCTAssertEqual(vm.totalAssetsKRW, 3_600_000, accuracy: 0.001)
    }

    func test_refresh_partialFailure_keepsSuccessfulAccounts() async {
        // provider1: 성공 (1,200,000원)
        // provider2: 실패
        let holding = makeKRWHolding()
        let account = Account(broker: .upbit, accountType: .cryptoWallet, name: "업비트",
                              holdings: [holding])
        let successProvider = MockBrokerProvider(broker: .upbit, account: account)
        let failProvider = FailingBrokerProvider(broker: .tossSecurities)
        let rateProvider = MockExchangeRateProvider(usdToKrw: 1300)

        let vm = HomeViewModel(
            providers: [successProvider, failProvider],
            exchangeRateProvider: rateProvider
        )
        await vm.refresh()

        // 성공한 provider 의 자산은 반영
        XCTAssertEqual(vm.totalAssetsKRW, 1_200_000, accuracy: 0.001)
        // 부분 실패이므로 에러 메시지 없음 (전체 실패가 아님)
        XCTAssertNil(vm.error, "부분 실패 시 에러 메시지를 표시하지 않아야 한다")
        XCTAssertFalse(vm.isLoading)
    }

    func test_refresh_allProvidersFail_setsError() async {
        let failProvider = FailingBrokerProvider(broker: .upbit)
        let rateProvider = MockExchangeRateProvider(usdToKrw: 1300)

        let vm = HomeViewModel(providers: [failProvider], exchangeRateProvider: rateProvider)
        await vm.refresh()

        XCTAssertNotNil(vm.error, "전체 실패 시 에러 메시지가 설정되어야 한다")
        XCTAssertEqual(vm.totalAssetsKRW, 0, accuracy: 0.001)
    }

    func test_refresh_multipleProviders_sumsTotalAssets() async {
        let rateProvider = MockExchangeRateProvider(usdToKrw: 1300)

        let h1 = makeKRWHolding(symbol: "BTC", currentPrice: 1_000_000)
        let h2 = makeKRWHolding(symbol: "ETH", currentPrice: 500_000)
        let acc1 = Account(broker: .upbit, accountType: .cryptoWallet, name: "업비트",
                           holdings: [h1])
        let acc2 = Account(broker: .tossSecurities, accountType: .general, name: "토스",
                           holdings: [h2])
        let p1 = MockBrokerProvider(broker: .upbit, account: acc1)
        let p2 = MockBrokerProvider(broker: .tossSecurities, account: acc2)

        let vm = HomeViewModel(providers: [p1, p2], exchangeRateProvider: rateProvider)
        await vm.refresh()

        XCTAssertEqual(vm.totalAssetsKRW, 1_500_000, accuracy: 0.001)
    }

    func test_refresh_noProviders_totalAssetsIsZero() async {
        let rateProvider = MockExchangeRateProvider(usdToKrw: 1300)
        let vm = HomeViewModel(providers: [], exchangeRateProvider: rateProvider)
        await vm.refresh()

        XCTAssertEqual(vm.totalAssetsKRW, 0, accuracy: 0.001)
        XCTAssertNil(vm.error)
    }

    func test_setSortMode_profitRate_sortsDescending() async {
        let rateProvider = MockExchangeRateProvider(usdToKrw: 1300)
        // h1: 수익률 10%, h2: 수익률 50%, h3: 수익률 30%
        let h1 = Holding(symbol: "A", name: "A", market: .krStock,
                         quantity: 1, averageCost: 100, currentPrice: 110, currency: .krw)
        let h2 = Holding(symbol: "B", name: "B", market: .krStock,
                         quantity: 1, averageCost: 100, currentPrice: 150, currency: .krw)
        let h3 = Holding(symbol: "C", name: "C", market: .krStock,
                         quantity: 1, averageCost: 100, currentPrice: 130, currency: .krw)
        let acc = Account(broker: .kis, accountType: .general, name: "KIS",
                          holdings: [h1, h2, h3])
        let provider = MockBrokerProvider(broker: .kis, account: acc)
        let vm = HomeViewModel(providers: [provider], exchangeRateProvider: rateProvider)
        await vm.refresh()

        vm.setSortMode(.profitRate)

        XCTAssertEqual(vm.holdings.map(\.symbol), ["B", "C", "A"],
                       "수익률 내림차순으로 정렬되어야 한다")
    }

    func test_todayProfitLoss_computed() async {
        let rateProvider = MockExchangeRateProvider(usdToKrw: 1300)
        // 매수 100원, 현재 120원 → 손익 +20원
        let holding = Holding(symbol: "X", name: "X", market: .krStock,
                              quantity: 1, averageCost: 100, currentPrice: 120, currency: .krw)
        let acc = Account(broker: .kis, accountType: .general, name: "KIS", holdings: [holding])
        let provider = MockBrokerProvider(broker: .kis, account: acc)

        let vm = HomeViewModel(providers: [provider], exchangeRateProvider: rateProvider)
        await vm.refresh()

        XCTAssertEqual(vm.todayProfit, 20, accuracy: 0.001)
        XCTAssertEqual(vm.todayProfitRate, 20, accuracy: 0.001)
    }
}

// MARK: - SettingsViewModel Tests

@MainActor
final class SettingsViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeViewModel(seed: [KeychainKey: String] = [:]) -> SettingsViewModel {
        let store = InMemorySecretStore(seed: seed)
        return SettingsViewModel(store: store)
    }

    // MARK: - Tests

    func test_loadAll_populatesInputValues() {
        let vm = makeViewModel(seed: [.upbitAccessKey: "access-abc"])
        vm.loadAll()

        XCTAssertEqual(vm.inputValues[.upbitAccessKey], "access-abc")
        // 저장되지 않은 키는 빈 문자열
        XCTAssertEqual(vm.inputValues[.upbitSecretKey], "")
    }

    func test_save_storesKeyInStore() {
        let store = InMemorySecretStore()
        let vm = SettingsViewModel(store: store)

        vm.save(key: .upbitAccessKey, value: "access-12345678")

        XCTAssertTrue(store.contains(.upbitAccessKey))
        XCTAssertEqual(try? store.load(for: .upbitAccessKey), "access-12345678")
        XCTAssertFalse(vm.isStatusError)
        XCTAssertNotNil(vm.statusMessage)
    }

    func test_save_shortValue_failsValidation() {
        let store = InMemorySecretStore()
        let vm = SettingsViewModel(store: store)

        vm.save(key: .upbitAccessKey, value: "short")

        XCTAssertFalse(store.contains(.upbitAccessKey))
        XCTAssertTrue(vm.isStatusError)
    }

    func test_save_emptyValue_deletesKey() {
        let store = InMemorySecretStore(seed: [.upbitAccessKey: "existing-key-value"])
        let vm = SettingsViewModel(store: store)

        vm.save(key: .upbitAccessKey, value: "")

        XCTAssertFalse(store.contains(.upbitAccessKey))
    }

    func test_delete_removesKeyFromStore() {
        let store = InMemorySecretStore(seed: [.kisAppKey: "some-app-key-12345"])
        let vm = SettingsViewModel(store: store)

        vm.delete(key: .kisAppKey)

        XCTAssertFalse(store.contains(.kisAppKey))
        XCTAssertEqual(vm.inputValues[.kisAppKey], "")
        XCTAssertFalse(vm.isStatusError)
    }

    func test_isStored_returnsCorrectValue() {
        let store = InMemorySecretStore(seed: [.tossClientId: "client-id-value-12"])
        let vm = SettingsViewModel(store: store)

        XCTAssertTrue(vm.isStored(.tossClientId))
        XCTAssertFalse(vm.isStored(.tossClientSecret))
    }

    func test_maskedValue_showsPrefixAndMask() {
        let store = InMemorySecretStore(seed: [.upbitSecretKey: "abcdefghij"])
        let vm = SettingsViewModel(store: store)

        let masked = vm.maskedValue(for: .upbitSecretKey)

        XCTAssertTrue(masked.hasPrefix("abcd"), "마스킹은 첫 4자를 노출해야 한다")
        XCTAssertTrue(masked.contains("••••"), "마스킹 문자를 포함해야 한다")
    }

    func test_maskedValue_unstored_returnsMiSeol() {
        let vm = makeViewModel()
        let masked = vm.maskedValue(for: .finnhubApiKey)
        XCTAssertEqual(masked, "미설정")
    }

    func test_brokerCredentials_containsSupportedBrokers() {
        let vm = makeViewModel()
        let brokerIds = vm.brokerCredentials.map(\.id)

        XCTAssertTrue(brokerIds.contains(.upbit), "업비트가 포함되어야 한다")
        XCTAssertTrue(brokerIds.contains(.tossSecurities), "토스증권이 포함되어야 한다")
        XCTAssertTrue(brokerIds.contains(.kis), "KIS가 포함되어야 한다")
    }

    func test_isConnected_allKeysPresent_returnsTrue() {
        let store = InMemorySecretStore(seed: [
            .upbitAccessKey: "access-12345678",
            .upbitSecretKey: "secret-12345678"
        ])
        let vm = SettingsViewModel(store: store)
        let credential = vm.brokerCredentials.first { $0.id == .upbit }!

        XCTAssertTrue(vm.isConnected(credential))
    }

    func test_isConnected_missingKey_returnsFalse() {
        let store = InMemorySecretStore(seed: [
            .upbitAccessKey: "access-12345678"
            // upbitSecretKey 없음
        ])
        let vm = SettingsViewModel(store: store)
        let credential = vm.brokerCredentials.first { $0.id == .upbit }!

        XCTAssertFalse(vm.isConnected(credential))
    }
}

// MARK: - AnalysisViewModel Tests

@MainActor
final class AnalysisViewModelTests: XCTestCase {

    func test_selectPeriod_updatesResult() async {
        let expectedResult = ProfitAnalysisResult(
            period: .month,
            profitKRW: 500_000,
            profitRate: 5.0
        )
        let useCase = MockProfitAnalysisUseCase(result: expectedResult)
        let vm = AnalysisViewModel(useCase: useCase)

        await vm.selectPeriod(.month)

        XCTAssertEqual(vm.selectedPeriod, .month)
        XCTAssertEqual(vm.result?.profitKRW ?? 0, 500_000, accuracy: 0.001)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }
}

// MARK: - DividendViewModel Tests

@MainActor
final class DividendViewModelTests: XCTestCase {

    func test_refresh_computesMonthlySummary() async {
        let jan = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let feb = Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 20))!
        let schedules = [
            DividendSchedule(symbol: "AAPL", exDividendDate: jan, paymentDate: jan,
                             amountPerShare: 0.24, totalAmount: 312_000, isConfirmed: true),
            DividendSchedule(symbol: "MSFT", exDividendDate: jan, paymentDate: jan,
                             amountPerShare: 0.68, totalAmount: 442_000, isConfirmed: false),
            DividendSchedule(symbol: "TSLA", exDividendDate: feb, paymentDate: feb,
                             amountPerShare: 0.50, totalAmount: 650_000, isConfirmed: true)
        ]
        let useCase = MockDividendUseCase(schedules: schedules)
        let vm = DividendViewModel(useCase: useCase, currentYear: 2025)

        await vm.refresh()

        // 1월 합산 확인
        let jan_monthly = vm.monthlyDividends.first { $0.month == 1 }
        XCTAssertNotNil(jan_monthly)
        XCTAssertEqual(jan_monthly!.totalKRW, 312_000 + 442_000, accuracy: 0.001)

        // 연간 총액
        XCTAssertEqual(vm.annualTotalKRW, 312_000 + 442_000 + 650_000, accuracy: 0.001)

        // 비어 있는 달은 0
        let mar_monthly = vm.monthlyDividends.first { $0.month == 3 }
        XCTAssertEqual(mar_monthly!.totalKRW, 0, accuracy: 0.001)
    }

    func test_refresh_error_setsErrorMessage() async {
        let useCase = FailingDividendUseCase()
        let vm = DividendViewModel(useCase: useCase, currentYear: 2025)

        await vm.refresh()

        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    func test_toggleDisplayMode_switches() {
        let useCase = MockDividendUseCase(schedules: [])
        let vm = DividendViewModel(useCase: useCase)

        XCTAssertEqual(vm.displayMode, .krw)
        vm.toggleDisplayMode()
        XCTAssertEqual(vm.displayMode, .usd)
        vm.toggleDisplayMode()
        XCTAssertEqual(vm.displayMode, .krw)
    }

    func test_availableYears_contains5Years() {
        let useCase = MockDividendUseCase(schedules: [])
        let vm = DividendViewModel(useCase: useCase, currentYear: 2025)

        XCTAssertEqual(vm.availableYears.count, 5)
        XCTAssertEqual(vm.availableYears.first, 2025)
        XCTAssertEqual(vm.availableYears.last, 2021)
    }
}
