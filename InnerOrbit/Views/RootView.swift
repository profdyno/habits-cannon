import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sparkles")
                }

            StatsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.xyaxis.line")
                }

            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "square.grid.2x2")
                }
        }
        .tint(OrbitTheme.accent)
    }
}
