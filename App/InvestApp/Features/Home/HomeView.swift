import SwiftUI
import InvestAppCore

/// 홈 탭 — 총자산 헤더 + 분석 숏컷 + 시세/평가 토글 + 보유 종목 리스트.
///
/// ASCII 목업:
/// ```
/// ┌────────────────────────────────┐
/// │  총 자산               ⚙️  │
/// │  279,149,692원                │
/// │  +32,323,665원  +13.10%       │
/// │                               │
/// │  [오늘] [전체] [1주] [1월] …  │
/// │                               │
/// │  ● 시세  ○ 평가               │
/// │                               │
/// │  BTC          60,000,000원    │
/// │  +10,000,000원  +20.00%       │
/// └────────────────────────────────┘
/// ```
struct HomeView: View {

    @Bindable var viewModel: HomeViewModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                // 총자산 헤더
                Section {
                    totalAssetsHeader
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

                // 분석 숏컷 버튼
                Section {
                    shortcutButtons
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))

                // 시세/평가 토글
                Section {
                    valuationToggle
                }
                .listRowBackground(Color.clear)

                // 정렬 피커
                Section {
                    sortPicker
                }
                .listRowBackground(Color.clear)

                // 보유 종목 리스트
                Section("보유 종목") {
                    if viewModel.isLoading {
                        ProgressView("불러오는 중…")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                    } else if let error = viewModel.error {
                        Text(error)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else if viewModel.holdings.isEmpty {
                        Text("보유 종목이 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.holdings) { holding in
                            HoldingRowView(holding: holding,
                                           usdToKrw: viewModel.totalAssetsKRW > 0 ? 1300 : 1300)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("투자 모아보기")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.profit)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showSettings) {
                // 설정 뷰 — 부모에서 container 를 통해 주입하는 것이 이상적이나
                // 여기서는 NavigationStack 컨텍스트에서 설정 화면을 여는 패턴을 시연
                Text("설정 화면")
            }
            .task {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Subviews

    private var totalAssetsHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("총 자산")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)

            Text(CurrencyFormat.formattedKRW(viewModel.totalAssetsKRW))
                .font(Theme.totalAssetsFont)
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Text(CurrencyFormat.formattedSignedKRW(viewModel.todayProfit))
                    .font(Theme.profitSubtitleFont)
                    .foregroundStyle(Theme.profitColor(viewModel.todayProfit))

                Text(CurrencyFormat.formattedPercent(viewModel.todayProfitRate))
                    .font(Theme.profitSubtitleFont)
                    .foregroundStyle(Theme.profitColor(viewModel.todayProfitRate))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var shortcutButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AnalysisPeriod.allCases, id: \.self) { period in
                    Button(period.displayName) {}
                        .buttonStyle(.bordered)
                        .tint(Theme.profit)
                        .font(.caption)
                }
            }
        }
    }

    private var valuationToggle: some View {
        HStack(spacing: 0) {
            ForEach(ValuationMode.allCases, id: \.self) { mode in
                Button {
                    viewModel.valuationMode = mode
                } label: {
                    Text(mode.displayName)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.valuationMode == mode
                                ? Theme.profit
                                : Color(.systemGray5)
                        )
                        .foregroundStyle(
                            viewModel.valuationMode == mode ? .white : .primary
                        )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    private var sortPicker: some View {
        Picker("정렬", selection: Binding(
            get: { viewModel.sortMode },
            set: { viewModel.setSortMode($0) }
        )) {
            ForEach(HoldingSortMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }
}

// MARK: - Holding Row

private struct HoldingRowView: View {
    let holding: Holding
    let usdToKrw: Double

    private var valueKRW: Double { holding.evaluatedValueKRW(usdToKrw: usdToKrw) }
    private var profit: Double {
        holding.currency == .usd
            ? holding.profitLoss * usdToKrw
            : holding.profitLoss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.name)
                        .font(Theme.holdingNameFont)
                    Text(holding.symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(CurrencyFormat.formattedKRW(valueKRW))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            HStack {
                Text(CurrencyFormat.formattedSignedKRW(profit))
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.profitColor(profit))
                Text(CurrencyFormat.formattedPercent(holding.profitLossRate))
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.profitColor(holding.profitLossRate))
                Spacer()
                marketBadge
            }
        }
        .padding(.vertical, 4)
    }

    private var marketBadge: some View {
        Text(holding.market.badgeLabel)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(holding.market.badgeColor.opacity(0.15))
            .foregroundStyle(holding.market.badgeColor)
            .clipShape(Capsule())
    }
}

// MARK: - Market Helpers

private extension Market {
    var badgeLabel: String {
        switch self {
        case .crypto:   return "코인"
        case .usStock:  return "미주"
        case .krStock:  return "국주"
        }
    }

    var badgeColor: Color {
        switch self {
        case .crypto:   return .orange
        case .usStock:  return Color(red: 0, green: 0.478, blue: 1)
        case .krStock:  return .red
        }
    }
}
