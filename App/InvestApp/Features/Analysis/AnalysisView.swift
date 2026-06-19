import SwiftUI
import InvestAppCore

/// 분석 탭 — 기간 세그먼트 피커 + 손익 요약 + 종목별 손익 리스트.
struct AnalysisView: View {

    @Bindable var viewModel: AnalysisViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 기간 세그먼트 피커
                periodPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider()
                    .padding(.top, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("분석 중…")
                    Spacer()
                } else if let error = viewModel.error {
                    Spacer()
                    Text(error)
                        .foregroundStyle(.secondary)
                        .padding()
                    Spacer()
                } else if let result = viewModel.result {
                    resultContent(result)
                } else {
                    Spacer()
                    Text("기간을 선택해 주세요.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("손익 분석")
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

    private func resultContent(_ result: ProfitAnalysisResult) -> some View {
        List {
            // 요약 섹션
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("손익")
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormat.formattedSignedKRW(result.profitKRW))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.profitColor(result.profitKRW))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("수익률")
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormat.formattedPercent(result.profitRate))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.profitColor(result.profitRate))
                    }
                }
                .padding(.vertical, 8)
            }

            // 종목별 손익 리스트
            if !result.holdingProfits.isEmpty {
                Section("종목별 손익") {
                    ForEach(result.holdingProfits) { hp in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hp.name)
                                    .font(Theme.holdingNameFont)
                                Text(hp.symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(CurrencyFormat.formattedSignedKRW(hp.profitKRW))
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.profitColor(hp.profitKRW))
                                Text(CurrencyFormat.formattedPercent(hp.profitRate))
                                    .font(.caption)
                                    .foregroundStyle(Theme.profitColor(hp.profitRate))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.refresh()
        }
    }
}
