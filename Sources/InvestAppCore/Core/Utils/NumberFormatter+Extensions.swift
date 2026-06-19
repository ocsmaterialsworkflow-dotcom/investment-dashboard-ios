import Foundation

/// 투자 앱에서 사용하는 통화·비율 포맷 헬퍼 모음.
///
/// Foundation 타입을 직접 확장하지 않아 네임스페이스 충돌을 방지한다.
public enum CurrencyFormat {

    // MARK: - KRW

    /// KRW 금액을 그룹 구분자와 "원" 접미사로 포맷한다.
    ///
    /// 예: `279149692` → `"279,149,692원"`
    public static func formattedKRW(_ value: Double) -> String {
        let formatted = krwFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return formatted + "원"
    }

    /// 부호를 포함한 KRW 금액을 포맷한다.
    ///
    /// 예: `32323665` → `"+32,323,665원"`, `-1000` → `"-1,000원"`
    public static func formattedSignedKRW(_ value: Double) -> String {
        let formatted = krwFormatter.string(from: NSNumber(value: abs(value))) ?? "\(Int(abs(value)))"
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(formatted)원"
    }

    // MARK: - Percent

    /// 비율을 부호 포함 퍼센트 문자열로 포맷한다 (소수점 2자리).
    ///
    /// 예: `13.1` → `"+13.10%"`, `-5.3` → `"-5.30%"`
    public static func formattedPercent(_ value: Double) -> String {
        let formatted = percentFormatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.2f", abs(value))
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(formatted)%"
    }

    // MARK: - Private Formatters

    private static let krwFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.groupingSize = 3
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()
}
