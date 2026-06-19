import Foundation
import Observation

// MARK: - Thin Protocol

/// 자산 추이 UseCase 얇은 프로토콜.
/// `TrendUseCase` 가 채택하도록 오케스트레이터가 연결한다.
public protocol TrendUseCaseProtocol: Sendable {
    /// 기간별 자산 스냅샷 시계열을 반환한다.
    func fetchSnapshots(period: AnalysisPeriod) async throws -> [AssetSnapshot]
}

// MARK: - TrendViewModel

/// 추이 탭 ViewModel.
///
/// - 기간별 자산/원금 시계열 데이터와 탭 tooltip 상태를 관리한다.
/// - 차트는 View 레이어에서 `snapshots` 를 직접 읽어 렌더링한다.
@MainActor
@Observable
public final class TrendViewModel {

    // MARK: - State

    /// 선택된 기간.
    public var selectedPeriod: AnalysisPeriod = .month

    /// 기간 내 자산 스냅샷 시계열.
    public var snapshots: [AssetSnapshot] = []

    /// 사용자가 차트 위를 탭/드래그할 때 강조되는 스냅샷.
    public var tooltipSnapshot: AssetSnapshot?

    /// 로딩 중 여부.
    public var isLoading: Bool = false

    /// 에러 메시지.
    public var error: String?

    // MARK: - Dependencies

    private let useCase: TrendUseCaseProtocol

    // MARK: - Init

    /// - Parameter useCase: 자산 추이 UseCase.
    public init(useCase: TrendUseCaseProtocol) {
        self.useCase = useCase
    }

    // MARK: - Public Methods

    /// 현재 선택된 기간의 스냅샷을 로드한다.
    public func refresh() async {
        await loadPeriod(selectedPeriod)
    }

    /// 기간 탭을 변경하고 데이터를 로드한다.
    public func selectPeriod(_ period: AnalysisPeriod) async {
        selectedPeriod = period
        await loadPeriod(period)
    }

    /// 차트에서 날짜 근처의 스냅샷을 찾아 tooltip 을 설정한다.
    /// - Parameter date: 사용자가 탭/드래그한 날짜.
    public func setTooltip(for date: Date) {
        guard !snapshots.isEmpty else {
            tooltipSnapshot = nil
            return
        }
        // 가장 가까운 날짜의 스냅샷을 선택
        tooltipSnapshot = snapshots.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    /// tooltip 을 닫는다.
    public func clearTooltip() {
        tooltipSnapshot = nil
    }

    // MARK: - Private

    private func loadPeriod(_ period: AnalysisPeriod) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            snapshots = try await useCase.fetchSnapshots(period: period)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
