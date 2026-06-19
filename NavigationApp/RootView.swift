import SwiftUI

struct RootView: View {
    @EnvironmentObject var recorder: RideRecorder
    @EnvironmentObject var navEngine: NavigationEngine

    @State private var selectedTab = 0
    @State private var activeRoute: GPXRoute?

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── Tab 1: Explore ──
            ExploreView(activeRoute: $activeRoute, selectedTab: $selectedTab)
                .tabItem {
                    Label("Explore", systemImage: "map")
                }
                .tag(0)

            // ── Tab 2: Ride ──
            RideView(activeRoute: $activeRoute)
                .tabItem {
                    Label("Ride", systemImage: "bicycle")
                }
                .tag(1)
                .badge(recorder.state == .active ? "•" : nil)

            // ── Tab 3: History ──
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)
        }
        .onChange(of: activeRoute?.id) { _, _ in
            // Keep the route source, singleton map state, and navigation engine in sync
            if let route = activeRoute {
                navEngine.setRoute(route)
            } else {
                navEngine.reset()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gpxFileReceived)) { notif in
            guard let url = notif.object as? URL else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            let parser = GPXParser()
            if let route = parser.parse(url: url) {
                activeRoute = route
                selectedTab = 0 // show it in Explore
            }
        }
    }
}
