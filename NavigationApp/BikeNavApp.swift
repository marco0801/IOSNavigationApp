import SwiftUI

@main
struct BikeNavApp: App {
    @StateObject private var locationManager  = LocationManager()
    @StateObject private var recorder         = RideRecorder()
    @StateObject private var navEngine        = NavigationEngine()
    @StateObject private var routeStore       = RouteStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(locationManager)
                .environmentObject(recorder)
                .environmentObject(navEngine)
                .environmentObject(routeStore)
                .onAppear {
                    locationManager.requestPermission()
                }
                .onOpenURL { url in
                    // Handles opening .gpx via Files app or share sheet
                    NotificationCenter.default.post(
                        name: .gpxFileReceived,
                        object: url
                    )
                }
        }
    }
}

extension Notification.Name {
    static let gpxFileReceived = Notification.Name("GPXFileReceived")
}
