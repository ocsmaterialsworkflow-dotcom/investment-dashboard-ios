import WidgetKit
import SwiftUI

// MARK: - App Group Key

/// App Group 식별자 (앱 타겟과 위젯 익스텐션이 공유).
/// NOTE: Xcode 프로젝트에서 App Group capability 를 동일하게 설정해야 한다.
private let appGroupIdentifier = "group.com.investapp.shared"
private let totalAssetsKey     = "com.investapp.widget.totalAssetsKRW"
private let lastUpdatedKey     = "com.investapp.widget.lastUpdated"

// MARK: - Timeline Entry

struct TotalAssetsEntry: TimelineEntry {
    let date: Date
    let totalAssetsKRW: Double
    let lastUpdated: Date?
    let isPlaceholder: Bool

    static var placeholder: TotalAssetsEntry {
        TotalAssetsEntry(
            date: Date(),
            totalAssetsKRW: 279_149_692,
            lastUpdated: nil,
            isPlaceholder: true
        )
    }
}

// MARK: - Timeline Provider

struct TotalAssetsTimelineProvider: TimelineProvider {

    typealias Entry = TotalAssetsEntry

    func placeholder(in context: Context) -> TotalAssetsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TotalAssetsEntry) -> Void) {
        completion(makeEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TotalAssetsEntry>) -> Void) {
        let entry = makeEntry(date: Date())
        // 15분마다 갱신 요청
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(refresh))
        completion(timeline)
    }

    // MARK: - Private

    private func makeEntry(date: Date) -> TotalAssetsEntry {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let total = defaults?.double(forKey: totalAssetsKey) ?? 0
        let updatedInterval = defaults?.double(forKey: lastUpdatedKey)
        let lastUpdated = updatedInterval.map { Date(timeIntervalSince1970: $0) }

        return TotalAssetsEntry(
            date: date,
            totalAssetsKRW: total,
            lastUpdated: lastUpdated,
            isPlaceholder: false
        )
    }
}

// MARK: - Widget View

struct TotalAssetsWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: TotalAssetsEntry

    private static let updatedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 헤더
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(profitPink)
                    .font(.caption)
                Text("투자 모아보기")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            // 총자산
            Text("총 자산")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if entry.isPlaceholder {
                Text("---원")
                    .font(.system(size: family == .systemSmall ? 18 : 24,
                                  weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .redacted(reason: .placeholder)
            } else {
                Text(formattedKRW(entry.totalAssetsKRW))
                    .font(.system(size: family == .systemSmall ? 18 : 24,
                                  weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            Spacer()

            // 마지막 업데이트
            if let updated = entry.lastUpdated {
                Text("업데이트: \(Self.updatedFormatter.string(from: updated))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("앱을 열어 새로고침하세요")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .containerBackground(Color(.systemBackground), for: .widget)
    }

    // MARK: - Helpers

    private var profitPink: Color {
        Color(red: 1, green: 0.176, blue: 0.333)
    }

    private func formattedKRW(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let s = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return s + "원"
    }
}

// MARK: - Widget Definition

struct InvestWidget: Widget {
    let kind: String = "com.investapp.totalAssetsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TotalAssetsTimelineProvider()) { entry in
            TotalAssetsWidgetView(entry: entry)
        }
        .configurationDisplayName("총 자산")
        .description("투자 포트폴리오의 총 자산을 홈 화면에서 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct InvestWidgetBundle: WidgetBundle {
    var body: some Widget {
        InvestWidget()
    }
}

// MARK: - App Group Helpers (used by main app target)

/// 앱 타겟에서 호출해 위젯 캐시를 갱신한다.
public func updateWidgetCache(totalAssetsKRW: Double) {
    let defaults = UserDefaults(suiteName: appGroupIdentifier)
    defaults?.set(totalAssetsKRW, forKey: totalAssetsKey)
    defaults?.set(Date().timeIntervalSince1970, forKey: lastUpdatedKey)
    WidgetCenter.shared.reloadTimelines(ofKind: "com.investapp.totalAssetsWidget")
}
