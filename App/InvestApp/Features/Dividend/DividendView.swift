import SwiftUI
import Charts
import InvestAppCore

/// 배당 탭 — 연도 드롭다운 + 월별 막대 차트 + 배당 일정 리스트(예상/확정 배지).
struct DividendView: View {

    @Bindable var viewModel: DividendViewModel

    var body: some View {
        NavigationStack {
            List {
                // 연도 + 표시 방식 컨트롤
                Section {
                    controlsRow
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.init(top: 0, leading: 16, bottom: 8, trailing: 16))

                // 연간 요약
                Section {
                    annualSummaryRow
                }

                // 월별 막대 차트
                Section("월별 배당금") {
                    monthlyBarChart
                        .frame(height: 200)
                        .listRowInsets(.init(top: 8, leading: 8, bottom: 8, trailing: 8))
                }

                // 배당 일정 리스트
                Section("배당 일정") {
                    if viewModel.isLoading {
                        ProgressView("불러오는 중…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if let error = viewModel.error {
                        Text(error).foregroundStyle(.secondary)
                    } else if viewModel.schedules.isEmpty {
                        Text("배당 일정이 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.schedules) { schedule in
                            DividendScheduleRow(
                                schedule: schedule,
                                displayMode: viewModel.displayMode
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("배당")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.refresh()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Subviews

    private var controlsRow: some View {
        HStack {
            // 연도 드롭다운
            Menu {
                ForEach(viewModel.availableYears, id: \.self) { year in
                    Button("\(year)년") {
                        Task { await viewModel.selectYear(year) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(viewModel.selectedYear)년")
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(Theme.profit)
            }

            Spacer()

            // 실수령액 / 외화 토글
            Button {
                viewModel.toggleDisplayMode()
            } label: {
                Text(viewModel.displayMode.displayName)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.profit.opacity(0.12))
                    .foregroundStyle(Theme.profit)
                    .clipShape(Capsule())
            }
        }
    }

    private var annualSummaryRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("연간 총 배당")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormat.formattedKRW(viewModel.annualTotalKRW))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.profit)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("배당 수익률")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormat.formattedPercent(viewModel.dividendYield))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.profitColor(viewModel.dividendYield))
            }
        }
        .padding(.vertical, 6)
    }

    private var monthlyBarChart: some View {
        Chart(viewModel.monthlyDividends) { monthly in
            BarMark(
                x: .value("월", "\(monthly.month)월"),
                y: .value(
                    "배당금",
                    viewModel.displayMode == .krw ? monthly.totalKRW : monthly.totalUSD
                )
            )
            .foregroundStyle(Theme.profit)
            .cornerRadius(4)
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
    }

    private func compactKRW(_ value: Double) -> String {
        if value >= 10_000_000 {
            return String(format: "%.0f만", value / 10_000)
        } else if value >= 1_000 {
            return String(format: "%.0f천", value / 1_000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Dividend Schedule Row

private struct DividendScheduleRow: View {
    let schedule: DividendSchedule
    let displayMode: DividendDisplayMode

    private var displayAmount: String {
        if displayMode == .krw {
            return CurrencyFormat.formattedKRW(schedule.totalAmount)
        } else {
            return String(format: "$%.2f", schedule.amountPerShare)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(schedule.symbol)
                        .font(Theme.holdingNameFont)
                    // 예상 / 확정 배지
                    Text(schedule.isConfirmed ? "확정" : "예상")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            schedule.isConfirmed
                                ? Theme.profit.opacity(0.15)
                                : Color.orange.opacity(0.15)
                        )
                        .foregroundStyle(schedule.isConfirmed ? Theme.profit : .orange)
                        .clipShape(Capsule())
                }
                Text("지급일: \(Self.dateFormatter.string(from: schedule.paymentDate))")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
                Text("배당락: \(Self.dateFormatter.string(from: schedule.exDividendDate))")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(displayAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.profit)
        }
        .padding(.vertical, 4)
    }
}
