import SwiftUI
import Charts
import InvestAppCore

/// 추이 탭 — 자산(핑크) + 원금(회색) 라인 차트, 탭 tooltip.
struct TrendView: View {

    @Bindable var viewModel: TrendViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 기간 피커
                periodPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider()
                    .padding(.top, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("추이 로딩 중…")
                    Spacer()
                } else if let error = viewModel.error {
                    Spacer()
                    Text(error).foregroundStyle(.secondary).padding()
                    Spacer()
                } else if viewModel.snapshots.isEmpty {
                    Spacer()
                    Text("데이터가 없습니다.")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    chartSection
                }
            }
            .navigationTitle("자산 추이")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Subviews

    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalysisPeriod.allCases, id: \.self) { period in
                    Button {
                        Task { await viewModel.selectPeriod(period) }
                    } label: {
                        Text(period.displayName)
                            .font(.subheadline)
                            .fontWeight(viewModel.selectedPeriod == period ? .bold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                viewModel.selectedPeriod == period
                                    ? Theme.profit
                                    : Color(.systemGray5)
                            )
                            .foregroundStyle(
                                viewModel.selectedPeriod == period ? .white : .primary
                            )
                            .clipShape(Capsule())
                    }
                    .animation(.easeInOut(duration: 0.15), value: viewModel.selectedPeriod)
                }
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tooltip 정보 표시
            if let tip = viewModel.tooltipSnapshot {
                tooltipView(tip)
                    .padding(.horizontal)
                    .padding(.top, 12)
            }

            // 라인 차트
            Chart {
                // 자산 총액 라인 (핑크)
                ForEach(viewModel.snapshots) { snap in
                    LineMark(
                        x: .value("날짜", snap.date),
                        y: .value("총자산", snap.totalValue)
                    )
                    .foregroundStyle(Theme.profit)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("날짜", snap.date),
                        y: .value("총자산", snap.totalValue)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Theme.profit.opacity(0.3), Theme.profit.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)
                }

                // 원금 라인 (회색)
                ForEach(viewModel.snapshots) { snap in
                    LineMark(
                        x: .value("날짜", snap.date),
                        y: .value("원금", snap.principal)
                    )
                    .foregroundStyle(Theme.principal)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                }

                // Tooltip 수직선
                if let tip = viewModel.tooltipSnapshot {
                    RuleMark(x: .value("선택", tip.date))
                        .foregroundStyle(Color(.systemGray4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    PointMark(
                        x: .value("날짜", tip.date),
                        y: .value("총자산", tip.totalValue)
                    )
                    .foregroundStyle(Theme.profit)
                    .symbolSize(60)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(compactKRW(v))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let origin = geo[proxy.plotAreaFrame].origin
                                    let location = CGPoint(
                                        x: drag.location.x - origin.x,
                                        y: drag.location.y - origin.y
                                    )
                                    if let date: Date = proxy.value(atX: location.x) {
                                        viewModel.setTooltip(for: date)
                                    }
                                }
                                .onEnded { _ in
                                    viewModel.clearTooltip()
                                }
                        )
                }
            }
            .frame(height: 260)
            .padding()

            // 범례
            legendView
                .padding(.horizontal)
        }
    }

    private func tooltipView(_ snap: AssetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snap.date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("총자산")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormat.formattedKRW(snap.totalValue))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.profit)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("원금")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormat.formattedKRW(snap.principal))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.principal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("손익")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormat.formattedSignedKRW(snap.profit))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.profitColor(snap.profit))
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var legendView: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Theme.profit)
                    .frame(width: 20, height: 2)
                Text("총자산")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Theme.principal)
                    .frame(width: 20, height: 2)
                Text("원금")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 8)
    }

    private func compactKRW(_ value: Double) -> String {
        if value >= 100_000_000 {
            return String(format: "%.0f억", value / 100_000_000)
        } else if value >= 10_000 {
            return String(format: "%.0f만", value / 10_000)
        }
        return String(format: "%.0f", value)
    }
}
