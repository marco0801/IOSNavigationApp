import SwiftUI
import CoreLocation
import Combine

struct RideView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var recorder: RideRecorder
    @EnvironmentObject var navEngine: NavigationEngine
    @EnvironmentObject var routeStore: RouteStore

    var activeRoute: GPXRoute?

    @State private var showSaveDialog = false
    @State private var rideName = ""
    @State private var savedRide: Ride?
    @State private var showSavedConfirmation = false
    @State private var followUser = true
    @State private var displayedRoute: GPXRoute? = nil

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // ── MAP (top half) ──
                ZStack(alignment: .top) {
                    BikeMapView(
                        route: displayedRoute,
                        recordedPoints: recorder.trackPoints.map(\.coordinate),
                        userLocation: locationManager.currentLocation?.coordinate,
                        heading: locationManager.currentHeading,
                        followUser: followUser,
                        navigationEngine: navEngine
                    )
                    .ignoresSafeArea(edges: .top)

                    // Turn instruction banner
                    if let turn = navEngine.currentTurn,
                       navEngine.distanceToNextTurn < 300,
                       recorder.state == .active {
                        TurnBanner(turn: turn, distance: navEngine.distanceToNextTurn)
                            .padding(.top, 16)
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Off-route warning
                    if navEngine.isOffRoute && displayedRoute != nil && recorder.state == .active {
                        OffRouteBanner()
                            .padding(.top, 80)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }
                }
                .frame(maxHeight: .infinity)

                // ── STATS (bottom half) ──
                StatsPanel()
                    .frame(height: 260)
                    .background(Color(.systemBackground))
            }

            // ── CONTROLS overlay at very bottom ──
            VStack {
                Spacer()
                ControlBar(
                    showSaveDialog: $showSaveDialog,
                    rideName: $rideName,
                    onReset: {
                        displayedRoute = nil
                        followUser = true
                    }
                )
                .padding(.bottom, 280) // above stats panel
                .padding(.horizontal)
            }
        }
        .onReceive(locationManager.$currentLocation.compactMap { $0 }) { location in
            recorder.addLocation(location)
            if displayedRoute != nil {
                navEngine.update(location: location)
            }
        }
        .alert("Save Ride", isPresented: $showSaveDialog) {
            TextField("Ride name", text: $rideName)
            Button("Save") { saveRide() }
            Button("Discard", role: .destructive) { discardRide() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Give your ride a name before saving.")
        }
        .overlay {
            if showSavedConfirmation {
                SavedToast()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: navEngine.currentTurn?.id)
        .animation(.easeInOut(duration: 0.3), value: navEngine.isOffRoute)
        .onAppear {
            displayedRoute = activeRoute
        }
    }

    private func saveRide() {
        guard var ride = recorder.stop() else { return }
        if !rideName.isEmpty { ride.name = rideName }
        routeStore.save(ride: ride)
        navEngine.reset()
        showSavedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSavedConfirmation = false
        }
    }

    private func discardRide() {
        _ = recorder.stop()
        navEngine.reset()
    }
}

// MARK: - Stats Panel

struct StatsPanel: View {
    @EnvironmentObject var recorder: RideRecorder
    @EnvironmentObject var navEngine: NavigationEngine

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            // Row 1 — primary stats
            HStack(spacing: 0) {
                StatCell(value: recorder.formattedSpeed,  unit: "km/h",  label: "SPEED")
                Divider().frame(height: 60)
                StatCell(value: recorder.formattedTime,   unit: "",      label: "TIME",     large: false)
                Divider().frame(height: 60)
                StatCell(value: recorder.formattedDistance, unit: "km",  label: "DISTANCE")
            }
            .frame(height: 80)

            Divider()

            // Row 2 — secondary stats
            HStack(spacing: 0) {
                StatCell(value: recorder.formattedAvgSpeed, unit: "km/h", label: "AVG")
                Divider().frame(height: 60)
                StatCell(value: recorder.formattedMaxSpeed, unit: "km/h", label: "MAX")
                Divider().frame(height: 60)
                StatCell(value: recorder.formattedElevation, unit: "",   label: "ELEV GAIN")
            }
            .frame(height: 80)

            Divider()

            // Route progress (only when following GPX)
            if navEngine.distanceToEnd > 0 {
                HStack(spacing: 0) {
                    StatCell(
                        value: String(format: "%.1f", navEngine.distanceToEnd / 1000),
                        unit: "km",
                        label: "TO FINISH"
                    )
                }
                .frame(height: 60)
                Divider()
            }
        }
    }
}

struct StatCell: View {
    let value: String
    let unit: String
    let label: String
    var large: Bool = true

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(large ? .system(size: 28, weight: .semibold, design: .rounded)
                                : .system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Control Bar

struct ControlBar: View {
    @EnvironmentObject var recorder: RideRecorder
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navEngine: NavigationEngine
    @Binding var showSaveDialog: Bool
    @Binding var rideName: String
    var onReset: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            switch recorder.state {
            case .idle:
                Button {
                    locationManager.startTracking()
                    recorder.start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RideButtonStyle(color: .green))

                Button {
                    navEngine.reset()
                    onReset?()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RideButtonStyle(color: .gray))

            case .active:
                Button {
                    recorder.pause()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RideButtonStyle(color: .orange))

                Button {
                    showSaveDialog = true
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RideButtonStyle(color: .red))

            case .paused:
                Button {
                    recorder.resume()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RideButtonStyle(color: .green))

                Button {
                    showSaveDialog = true
                } label: {
                    Label("Finish", systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RideButtonStyle(color: .red))
            }
        }
    }
}

struct RideButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Turn Banner

struct TurnBanner: View {
    let turn: TurnInstruction
    let distance: Double

    var distanceText: String {
        distance < 100
            ? String(format: "%.0f m", distance)
            : String(format: "%.0f m", distance)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: turn.direction.icon)
                .font(.title)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(turn.direction.label)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("in \(distanceText)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(12)
        .background(.blue, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 4)
    }
}

struct OffRouteBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Off route — return to the track")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .padding(10)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct SavedToast: View {
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Ride saved!")
                    .font(.subheadline.bold())
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 120)
        }
    }
}
