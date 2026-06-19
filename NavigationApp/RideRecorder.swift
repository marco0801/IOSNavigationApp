import Foundation
import CoreLocation
import Combine

enum RideState {
    case idle, active, paused
}

class RideRecorder: ObservableObject {
    @Published var state: RideState = .idle
    @Published var trackPoints: [TrackPoint] = []

    // Live stats
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0       // meters
    @Published var currentSpeed: Double = 0   // m/s
    @Published var maxSpeed: Double = 0       // m/s
    @Published var elevationGain: Double = 0  // meters
    @Published var currentAltitude: Double = 0

    var avgSpeed: Double {
        elapsedTime > 0 ? distance / elapsedTime : 0
    }

    // Formatted helpers
    var formattedTime: String {
        let h = Int(elapsedTime) / 3600
        let m = (Int(elapsedTime) % 3600) / 60
        let s = Int(elapsedTime) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var formattedDistance: String {
        let km = distance / 1000
        return String(format: "%.2f", km)
    }

    var formattedSpeed: String {
        String(format: "%.1f", currentSpeed * 3.6)
    }

    var formattedAvgSpeed: String {
        String(format: "%.1f", avgSpeed * 3.6)
    }

    var formattedMaxSpeed: String {
        String(format: "%.1f", maxSpeed * 3.6)
    }

    var formattedElevation: String {
        String(format: "%.0f m", elevationGain)
    }

    // Private
    private var timer: Timer?
    private var lastLocation: CLLocation?
    private var lastAltitude: Double?
    private var pausedTime: TimeInterval = 0
    private var timerStartDate: Date?

    // MARK: - Controls

    func start() {
        guard state == .idle else { return }
        reset()
        state = .active
        startTimer()
    }

    func pause() {
        guard state == .active else { return }
        state = .paused
        pausedTime = elapsedTime
        stopTimer()
    }

    func resume() {
        guard state == .paused else { return }
        state = .active
        startTimer()
    }

    func stop() -> Ride? {
        guard state != .idle else { return nil }
        let savedState = state
        state = .idle
        stopTimer()

        guard !trackPoints.isEmpty, savedState != .idle else { return nil }

        let ride = Ride(
            name: "Ride on \(formattedDate())",
            date: trackPoints.first?.timestamp ?? Date(),
            trackPoints: trackPoints,
            distance: distance,
            duration: elapsedTime,
            elevationGain: elevationGain,
            maxSpeed: maxSpeed,
            avgSpeed: avgSpeed
        )
        return ride
    }

    func reset() {
        trackPoints = []
        elapsedTime = 0
        distance = 0
        currentSpeed = 0
        maxSpeed = 0
        elevationGain = 0
        currentAltitude = 0
        lastLocation = nil
        lastAltitude = nil
        pausedTime = 0
    }

    // MARK: - Location Updates

    func addLocation(_ location: CLLocation) {
        guard state == .active else { return }

        let point = TrackPoint(location: location)
        trackPoints.append(point)

        // Update speed
        currentSpeed = point.speed
        if point.speed > maxSpeed { maxSpeed = point.speed }

        // Update distance
        if let last = lastLocation {
            let delta = location.distance(from: last)
            if delta > 2 { // filter GPS noise
                distance += delta
                lastLocation = location
            }
        } else {
            lastLocation = location
        }

        // Update elevation gain
        currentAltitude = location.altitude
        if let lastAlt = lastAltitude {
            let altDelta = location.altitude - lastAlt
            if altDelta > 0 { elevationGain += altDelta }
        }
        lastAltitude = location.altitude
    }

    // MARK: - Timer

    private func startTimer() {
        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.timerStartDate else { return }
            self.elapsedTime = self.pausedTime + Date().timeIntervalSince(start)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerStartDate = nil
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: Date())
    }
}
