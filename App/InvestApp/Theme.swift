import SwiftUI

/// 투자 모아보기 앱 공통 색상/스타일 정의.
public enum Theme {

    // MARK: - Colors

    /// 수익 색상: 핑크 (#FF2D55).
    public static let profit = Color(red: 1, green: 0.176, blue: 0.333)

    /// 손실 색상: 파랑 (#007AFF).
    public static let loss   = Color(red: 0, green: 0.478, blue: 1)

    /// 배경 색상: 시스템 배경.
    public static let background = Color(.systemBackground)

    /// 보조 배경 색상: 그룹 배경.
    public static let secondaryBackground = Color(.secondarySystemBackground)

    /// 원금 추이 선 색상: 회색.
    public static let principal = Color(.systemGray3)

    // MARK: - Helper

    /// 수익/손실에 따른 색상을 반환한다.
    /// - Parameter value: 손익 금액 또는 수익률. 0 이상이면 수익 핑크, 미만이면 손실 파랑.
    public static func profitColor(_ value: Double) -> Color {
        value >= 0 ? profit : loss
    }

    // MARK: - Typography

    /// 총자산 헤더 숫자 폰트.
    public static let totalAssetsFont: Font = .system(size: 32, weight: .bold, design: .rounded)

    /// 손익 부제 폰트.
    public static let profitSubtitleFont: Font = .system(size: 14, weight: .medium)

    /// 종목명 폰트.
    public static let holdingNameFont: Font = .system(size: 16, weight: .semibold)

    /// 보조 레이블 폰트.
    public static let captionFont: Font = .caption
}
