import Foundation
import Observation

// MARK: - Models

/// 비중 분석 세그먼트 (축 기준).
public enum WeightDimension: String, CaseIterable, Sendable {
    /// 종목별.
    case holding  = "종목별"
    /// 자산 유형별 (crypto/usStock/krStock).
    case type     = "유형별"
    /// 계좌별.
    case account  = "계좌별"
    /// 국가별.
    case country  = "국가별"
    /// 거래소별.
    case exchange = "거래소별"

    /// 화면 표시용 이름.
    public var displayName: String { rawValue }
}

/// 비중 1 슬라이스.
public struct WeightSlice: Identifiable, Sendable {
    public let id: UUID
    /// 레이블 (종목명, 유형명, 계좌명 등).
    public let label: String
    /// KRW 기준 평가금액.
    public let valueKRW: Double
    /// 전체 대비 비율 (0~100).
    public let percent: Double

    public init(
        id: UUID = UUID(),
        label: String,
        valueKRW: Double,
        percent: Double
    ) {
        self.id = id
        self.label = label
        self.valueKRW = valueKRW
        self.percent = percent
    }
}

// MARK: - Thin Protocol

/// 비중 분석 UseCase 얇은 프로토콜.
/// `PortfolioWeightUseCase` 가 채택하도록 오케스트레이터가 연결한다.
public protocol PortfolioWeightUseCaseProtocol: Sendable {
    /// 주어진 기준으로 비중 슬라이스를 계산해 반환한다.
    func execute(dimension: WeightDimension) async throws -> [WeightSlice]
}

// MARK: - PortfolioViewModel

/// 비중 탭 ViewModel.
///
/// - 세그먼트(종목별/유형별/계좌별) 전환 시 UseCase 를 통해 비중을 계산한다.
/// - 도넛 차트용 `slices` 를 제공한다.
@MainActor
@Observable
public final class PortfolioViewModel {

    // MARK: - State

    /// 선택된 비중 세그먼트.
    public var selectedDimension: WeightDimension = .holding

    /// 현재 세그먼트의 비중 슬라이스.
    public var slices: [WeightSlice] = []

    /// 로딩 중 여부.
    public var isLoading: Bool = false

    /// 에러 메시지.
    public var error: String?

    // MARK: - Dependencies

    private let useCase: PortfolioWeightUseCaseProtocol

    // MARK: - Init

    /// - Parameter useCase: 비중 분석 UseCase.
    public init(useCase: PortfolioWeightUseCaseProtocol) {
        self.useCase = useCase
    }

    // MARK: - Public Methods

    /// 현재 선택된 세그먼트로 비중을 로드한다.
    public func refresh() async {
        await loadDimension(selectedDimension)
    }

    /// 세그먼트를 변경하고 데이터를 로드한다.
    public func selectDimension(_ dimension: WeightDimension) async {
        selectedDimension = dimension
        await loadDimension(dimension)
    }

    // MARK: - Private

    private func loadDimension(_ dimension: WeightDimension) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            slices = try await useCase.execute(dimension: dimension)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
