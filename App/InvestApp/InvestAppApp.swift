import SwiftUI
import InvestAppCore

@main
struct InvestAppApp: App {

    // MARK: - DI Container

    @State private var container = AppDependencyContainer()

    // MARK: - Scene Phase

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await container.homeViewModel.refresh()
                        }
                    }
                }
        }
    }
}

// MARK: - ContentView (Root Tab)

struct ContentView: View {
    let container: AppDependencyContainer

    var body: some View {
        TabView {
            HomeView(viewModel: container.homeViewModel)
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            AnalysisView(viewModel: container.analysisViewModel)
                .tabItem {
                    Label("분석", systemImage: "chart.bar.fill")
                }

            DividendView(viewModel: container.dividendViewModel)
                .tabItem {
                    Label("배당", systemImage: "dollarsign.circle.fill")
                }

            TrendView(viewModel: container.trendViewModel)
                .tabItem {
                    Label("추이", systemImage: "chart.line.uptrend.xyaxis")
                }

            PortfolioView(viewModel: container.portfolioViewModel)
                .tabItem {
                    Label("비중", systemImage: "chart.pie.fill")
                }
        }
        .tint(Theme.profit)
        .sheet(isPresented: .constant(false)) {
            // 설정 화면은 HomeView 상단의 기어 아이콘에서 진입
            SettingsView(viewModel: container.settingsViewModel)
        }
    }
}
