import Foundation
import Observation

// MARK: - Thin Protocol

/// 기간별 손익 분석 결과 1건.
public struct ProfitAnalysisResult: Sendable {
    public let period: AnalysisPeriod
    public let profitKRW: Double
    public let profitRate: Double
    public let holdingProfits: [HoldingProfit]

    public init(
        period: AnalysisPeriod,
        profitKRW: Double,
        profitRate: Double,
        holdingProfits: [HoldingProfit] = []
    ) {
        self.period = period
        self.profitKRW = profitKRW
        self.profitRate = profitRate
        self.holdingProfits = holdingProfits
    }
}

/// 종목별 손익 요약.
public struct HoldingProfit: Identifiable, Sendable {
    public let id: UUID
    public let symbol: String
    public let name: String
    public let profitKRW: Double
    public let profitRate: Double

    public init(
        id: UUID = UUID(),
        symbol: String,
        name: String,
        profitKRW: Double,
        profitRate: Double
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.profitKRW = profitKRW
        self.profitRate = profitRate
    }
}

/// 손익 분석 UseCase 얇은 프로토콜.
/// `ProfitAnalysisUseCase` 가 채택하도록 오케스트레이터가 연결한다.
public protocol ProfitAnalysisUseCaseProtocol: Sendable {
    func execute(period: AnalysisPeriod) async throws -> ProfitAnalysisResult
}

// MARK: - AnalysisViewModel

/// 분석 탭 ViewModel.
///
/// - 기간 탭(AnalysisPeriod) 전환 시 UseCase 를 통해 손익을 계산한다.
@MainActor
@Observable
public final class AnalysisViewModel {

    // MARK: - State

    /// 선택된 분석 기간.
    public var selectedPeriod: AnalysisPeriod = .month

    /// 현재 기간의 분석 결과.
    public var result: ProfitAnalysisResult?

    /// 로딩 중 여부.
    public var isLoading: Bool = false

    /// 에러 메시지.
    public var error: String?

    // MARK: - Dependencies

    private let useCase: ProfitAnalysisUseCaseProtocol

    // MARK: - Init

    /// - Parameter useCase: 손익 분석 UseCase.
    public init(useCase: ProfitAnalysisUseCaseProtocol) {
        self.useCase = useCase
    }

    // MARK: - Public Methods

    /// 선택된 기간으로 손익 분석을 실행한다.
    public func refresh() async {
        await loadPeriod(selectedPeriod)
    }

    /// 기간 탭을 변경하고 데이터를 로드한다.
    public func selectPeriod(_ period: AnalysisPeriod) async {
        selectedPeriod = period
        await loadPeriod(period)
    }

    // MARK: - Private

    private func loadPeriod(_ period: AnalysisPeriod) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            result = try await useCase.execute(period: period)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
