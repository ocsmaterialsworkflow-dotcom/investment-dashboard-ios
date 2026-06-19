import SwiftUI
import Charts
import InvestAppCore

/// 비중 탭 — 세그먼트 피커 + 도넛 차트(SectorMark) + 비중 리스트.
struct PortfolioView: View {

    @Bindable var viewModel: PortfolioViewModel

    /// 도넛 차트에 사용할 색상 팔레트 (순환).
    private let palette: [Color] = [
        Theme.profit,
        Color(red: 0, green: 0.478, blue: 1),   // 파랑
        Color(red: 1, green: 0.584, blue: 0),    // 주황
        Color(red: 0.196, green: 0.843, blue: 0.294), // 녹색
        Color(red: 0.694, green: 0.322, blue: 0.871), // 보라
        Color(red: 1, green: 0.8, blue: 0),      // 노랑
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 세그먼트 피커
                dimensionPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider()
                    .padding(.top, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("비중 계산 중…")
                    Spacer()
                } else if let error = viewModel.error {
                    Spacer()
                    Text(error).foregroundStyle(.secondary).padding()
                    Spacer()
                } else if viewModel.slices.isEmpty {
                    Spacer()
                    Text("데이터가 없습니다.")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            donutChart
                            sliceList
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("자산 비중")
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

    private var dimensionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WeightDimension.allCases, id: \.self) { dim in
                    Button {
                        Task { await viewModel.selectDimension(dim) }
                    } label: {
                        Text(dim.displayName)
                            .font(.subheadline)
                            .fontWeight(viewModel.selectedDimension == dim ? .bold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                viewModel.selectedDimension == dim
                                    ? Theme.profit
                                    : Color(.systemGray5)
                            )
                            .foregroundStyle(
                                viewModel.selectedDimension == dim ? .white : .primary
                            )
                            .clipShape(Capsule())
                    }
                    .animation(.easeInOut(duration: 0.15), value: viewModel.selectedDimension)
                }
            }
        }
    }

    private var donutChart: some View {
        Chart(Array(viewModel.slices.enumerated()), id: \.element.id) { index, slice in
            SectorMark(
                angle: .value("비중", slice.percent),
                innerRadius: .ratio(0.55),
                angularInset: 1.5
            )
            .foregroundStyle(palette[index % palette.count])
            .cornerRadius(4)
        }
        .frame(width: 220, height: 220)
        .overlay {
            VStack(spacing: 4) {
                Text("총\n\(viewModel.slices.count)개")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var sliceList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.slices.enumerated()), id: \.element.id) { index, slice in
                HStack(spacing: 12) {
                    Circle()
                        .fill(palette[index % palette.count])
                        .frame(width: 12, height: 12)

                    Text(slice.label)
                        .font(.subheadline)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(CurrencyFormat.formattedKRW(slice.valueKRW))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(String(format: "%.1f%%", slice.percent))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)

                if index < viewModel.slices.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
