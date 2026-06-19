import Foundation
import Observation

// MARK: - Models

/// 월별 배당 합산.
public struct MonthlyDividend: Identifiable, Sendable {
    public let id: UUID
    /// 1~12 월.
    public let month: Int
    /// KRW 환산 배당금 합산.
    public let totalKRW: Double
    /// 외화(USD) 배당금 합산.
    public let totalUSD: Double

    public init(
        id: UUID = UUID(),
        month: Int,
        totalKRW: Double,
        totalUSD: Double
    ) {
        self.id = id
        self.month = month
        self.totalKRW = totalKRW
        self.totalUSD = totalUSD
    }
}

// MARK: - Thin Protocol

/// 배당 UseCase 얇은 프로토콜.
/// `DividendUseCase` 가 채택하도록 오케스트레이터가 연결한다.
public protocol DividendUseCaseProtocol: Sendable {
    /// 특정 연도의 배당 일정 목록을 반환한다.
    func fetchSchedules(year: Int) async throws -> [DividendSchedule]
}

// MARK: - Display Mode

/// 배당 금액 표시 방식.
public enum DividendDisplayMode: String, CaseIterable, Sendable {
    /// 실수령액 (KRW).
    case krw = "실수령액(KRW)"
    /// 외화 원본 (USD).
    case usd = "외화(USD)"

    /// 화면 표시용 이름.
    public var displayName: String { rawValue }
}

// MARK: - DividendViewModel

/// 배당 탭 ViewModel.
///
/// - 연도 선택 드롭다운, 월별 막대 차트 데이터, 배당 일정 리스트를 제공한다.
/// - `displayMode` 토글로 KRW / USD 전환.
@MainActor
@Observable
public final class DividendViewModel {

    // MARK: - State

    /// 선택된 연도 (예: 2025).
    public var selectedYear: Int

    /// 선택 가능한 연도 목록 (현재 연도 기준 최근 5년).
    public var availableYears: [Int] = []

    /// 월별 배당 합산 (1~12).
    public var monthlyDividends: [MonthlyDividend] = []

    /// 원본 일정 목록.
    public var schedules: [DividendSchedule] = []

    /// 배당 표시 방식 (실수령액 / 외화).
    public var displayMode: DividendDisplayMode = .krw

    /// 연간 총 배당금 (KRW).
    public var annualTotalKRW: Double = 0

    /// 배당 수익률 (%). 총자산 기준으로 오케스트레이터가 주입.
    public var dividendYield: Double = 0

    /// 로딩 중 여부.
    public var isLoading: Bool = false

    /// 에러 메시지.
    public var error: String?

    // MARK: - Dependencies

    private let useCase: DividendUseCaseProtocol

    // MARK: - Init

    /// - Parameters:
    ///   - useCase: 배당 UseCase.
    ///   - currentYear: 기준 연도 (테스트 주입용; 기본값은 현재 연도).
    public init(
        useCase: DividendUseCaseProtocol,
        currentYear: Int = Calendar.current.component(.year, from: Date())
    ) {
        self.useCase = useCase
        self.selectedYear = currentYear
        // 최근 5년
        self.availableYears = (0..<5).map { currentYear - $0 }
    }

    // MARK: - Public Methods

    /// 선택된 연도의 배당 데이터를 로드한다.
    public func refresh() async {
        await loadYear(selectedYear)
    }

    /// 연도를 변경하고 데이터를 로드한다.
    public func selectYear(_ year: Int) async {
        selectedYear = year
        await loadYear(year)
    }

    /// 표시 방식을 토글한다 (KRW ↔ USD).
    public func toggleDisplayMode() {
        displayMode = displayMode == .krw ? .usd : .krw
    }

    // MARK: - Private

    private func loadYear(_ year: Int) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let loaded = try await useCase.fetchSchedules(year: year)
            schedules = loaded
            computeMonthlySummary(from: loaded)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func computeMonthlySummary(from list: [DividendSchedule]) {
        var byMonth: [Int: (krw: Double, usd: Double)] = [:]
        for schedule in list {
            let month = Calendar.current.component(.month, from: schedule.paymentDate)
            let prev = byMonth[month] ?? (krw: 0, usd: 0)
            // totalAmount 는 KRW, amountPerShare 는 USD
            byMonth[month] = (
                krw: prev.krw + schedule.totalAmount,
                usd: prev.usd + schedule.amountPerShare
            )
        }

        monthlyDividends = (1...12).map { month in
            let entry = byMonth[month] ?? (krw: 0, usd: 0)
            return MonthlyDividend(month: month, totalKRW: entry.krw, totalUSD: entry.usd)
        }

        annualTotalKRW = list.reduce(0) { $0 + $1.totalAmount }
    }
}
