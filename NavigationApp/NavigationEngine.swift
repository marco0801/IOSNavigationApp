import Foundation
import CoreLocation
import Combine

class NavigationEngine: ObservableObject {
    @Published var currentTurn: TurnInstruction?
    @Published var distanceToNextTurn: Double = 0
    @Published var distanceToEnd: Double = 0
    @Published var progressIndex: Int = 0
    @Published var isOffRoute: Bool = false

    private var currentRoute: GPXRoute?
    private var distancesFromStart: [Double] = []

    // How close to a turn before we show it (meters)
    private let turnAlertDistance: Double = 80
    // How far off route before we warn (meters)
    private let offRouteThreshold: Double = 50

    // MARK: - Setup

    func setRoute(_ route: GPXRoute) {
        currentRoute = route
        precomputeDistances(route.trackPoints)
        distanceToEnd = distancesFromStart.last ?? 0
        currentTurn = route.turns.first
        distanceToNextTurn = 0
    }

    func reset() {
        currentRoute = nil
        distancesFromStart = []
        currentTurn = nil
        distanceToNextTurn = 0
        distanceToEnd = 0
        progressIndex = 0
        isOffRoute = false
    }

    // MARK: - Update with new location

    func update(location: CLLocation) {
        guard let route = currentRoute, !route.trackPoints.isEmpty else { return }

        // Find closest point on route
        let (closestIndex, closestDist) = findClosestPoint(to: location, in: route.trackPoints)
        progressIndex = closestIndex
        isOffRoute = closestDist > offRouteThreshold

        // Distance remaining
        guard closestIndex < distancesFromStart.count else { return }
        let totalDist = distancesFromStart.last ?? 0
        let coveredDist = distancesFromStart[closestIndex]
        distanceToEnd = max(0, totalDist - coveredDist)

        // Find next upcoming turn
        updateNextTurn(coveredDistance: coveredDist, turns: route.turns)
    }

    // MARK: - Turn Detection (Static)

    static func detectTurns(in points: [CLLocationCoordinate2D]) -> [TurnInstruction] {
        guard points.count > 2 else { return [] }

        var turns: [TurnInstruction] = []
        var distFromStart = 0.0
        let smoothingWindow = 5 // look ahead/behind for smoother bearing calc

        for i in smoothingWindow..<(points.count - smoothingWindow) {
            let prevIndex = max(0, i - smoothingWindow)
            let nextIndex = min(points.count - 1, i + smoothingWindow)

            let inBearing  = bearing(from: points[prevIndex], to: points[i])
            let outBearing = bearing(from: points[i], to: points[nextIndex])

            let delta = bearingDelta(from: inBearing, to: outBearing)

            // Accumulate distance
            let a = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let b = CLLocation(latitude: points[i].latitude,   longitude: points[i].longitude)
            distFromStart += a.distance(from: b)

            // Classify turn by angle
            let direction: TurnInstruction.TurnDirection?
            switch abs(delta) {
            case 150...180: direction = .uTurn
            case 60..<150:  direction = delta > 0 ? .right : .left
            case 25..<60:   direction = delta > 0 ? .slightRight : .slightLeft
            default:        direction = nil
            }

            guard let dir = direction else { continue }

            // Avoid duplicate turns within 30m
            if let last = turns.last, distFromStart - last.distanceFromStart < 30 {
                turns.removeLast()
            }

            turns.append(TurnInstruction(
                coordinate: points[i],
                pointIndex: i,
                direction: dir,
                distanceFromStart: distFromStart
            ))
        }

        return turns
    }

    // MARK: - Private Helpers

    private func precomputeDistances(_ points: [CLLocationCoordinate2D]) {
        distancesFromStart = [0]
        var total = 0.0
        for i in 1..<points.count {
            let a = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let b = CLLocation(latitude: points[i].latitude,   longitude: points[i].longitude)
            total += a.distance(from: b)
            distancesFromStart.append(total)
        }
    }

    private func findClosestPoint(to location: CLLocation,
                                   in points: [CLLocationCoordinate2D]) -> (Int, Double) {
        var closestIndex = progressIndex
        var closestDist = Double.infinity

        // Search window around current progress to save CPU
        let start = max(0, progressIndex - 10)
        let end   = min(points.count - 1, progressIndex + 50)

        for i in start...end {
            let pt = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            let d = location.distance(from: pt)
            if d < closestDist {
                closestDist = d
                closestIndex = i
            }
        }
        return (closestIndex, closestDist)
    }

    private func updateNextTurn(coveredDistance: Double, turns: [TurnInstruction]) {
        // Find next turn ahead of us
        guard let nextTurn = turns.first(where: { $0.distanceFromStart > coveredDistance }) else {
            currentTurn = nil
            distanceToNextTurn = 0
            return
        }
        currentTurn = nextTurn
        distanceToNextTurn = nextTurn.distanceFromStart - coveredDistance
    }

    // MARK: - Bearing Math

    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude  * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    static func bearingDelta(from b1: Double, to b2: Double) -> Double {
        var delta = b2 - b1
        while delta >  180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }
}
