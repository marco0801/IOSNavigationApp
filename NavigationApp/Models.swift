import Foundation
import CoreLocation

// MARK: - Track Point
struct TrackPoint: Codable {
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var timestamp: Date
    var speed: Double // m/s

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.timestamp = location.timestamp
        self.speed = max(0, location.speed)
    }
}

// MARK: - Saved Ride
struct Ride: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var date: Date
    var trackPoints: [TrackPoint]

    var distance: Double        // meters
    var duration: TimeInterval  // seconds
    var elevationGain: Double   // meters
    var maxSpeed: Double        // m/s
    var avgSpeed: Double        // m/s

    var formattedDistance: String {
        let km = distance / 1000
        return String(format: "%.1f km", km)
    }

    var formattedDuration: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var formattedAvgSpeed: String {
        String(format: "%.1f km/h", avgSpeed * 3.6)
    }

    var formattedMaxSpeed: String {
        String(format: "%.1f km/h", maxSpeed * 3.6)
    }

    var formattedElevation: String {
        String(format: "%.0f m", elevationGain)
    }
}

// MARK: - GPX Route (imported)
struct GPXRoute: Identifiable {
    var id: UUID = UUID()
    var name: String
    var trackPoints: [CLLocationCoordinate2D]
    var waypoints: [GPXWaypoint]
    var turns: [TurnInstruction]

    var totalDistance: Double {
        guard trackPoints.count > 1 else { return 0 }
        var dist = 0.0
        for i in 1..<trackPoints.count {
            let a = CLLocation(latitude: trackPoints[i-1].latitude, longitude: trackPoints[i-1].longitude)
            let b = CLLocation(latitude: trackPoints[i].latitude, longitude: trackPoints[i].longitude)
            dist += a.distance(from: b)
        }
        return dist
    }
}

struct GPXWaypoint {
    var coordinate: CLLocationCoordinate2D
    var name: String?
}

// MARK: - Turn Instruction
struct TurnInstruction: Identifiable {
    var id: UUID = UUID()
    var coordinate: CLLocationCoordinate2D
    var pointIndex: Int
    var direction: TurnDirection
    var distanceFromStart: Double // meters

    enum TurnDirection {
        case left, right, slightLeft, slightRight, uTurn, straight

        var icon: String {
            switch self {
            case .left:        return "arrow.turn.up.left"
            case .right:       return "arrow.turn.up.right"
            case .slightLeft:  return "arrow.up.left"
            case .slightRight: return "arrow.up.right"
            case .uTurn:       return "arrow.uturn.left"
            case .straight:    return "arrow.up"
            }
        }

        var label: String {
            switch self {
            case .left:        return "Turn left"
            case .right:       return "Turn right"
            case .slightLeft:  return "Bear left"
            case .slightRight: return "Bear right"
            case .uTurn:       return "U-turn"
            case .straight:    return "Continue straight"
            }
        }
    }
}
