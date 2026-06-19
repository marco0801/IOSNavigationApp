import SwiftUI
import MapKit

struct BikeMapView: UIViewRepresentable {
    var route: GPXRoute?
    var recordedPoints: [CLLocationCoordinate2D]
    var userLocation: CLLocationCoordinate2D?
    var heading: Double
    var followUser: Bool
    var navigationEngine: NavigationEngine?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = .followWithHeading
        map.showsCompass = true
        map.showsScale = true
        map.mapType = .standard
        return map
    }
    
    mutating func reset() {
        self.route = nil
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Remove old overlays and annotations
        map.removeOverlays(map.overlays)
        let nonUserAnnotations = map.annotations.filter { !($0 is MKUserLocation) }
        map.removeAnnotations(nonUserAnnotations)

        // Draw imported GPX route (grey)
        if let route = route, !route.trackPoints.isEmpty {
            let polyline = MKPolyline(coordinates: route.trackPoints, count: route.trackPoints.count)
            polyline.title = "gpx_route"
            map.addOverlay(polyline, level: .aboveRoads)

            // Add waypoint pins
            for wpt in route.waypoints {
                let pin = MKPointAnnotation()
                pin.coordinate = wpt.coordinate
                pin.title = wpt.name ?? "Waypoint"
                map.addAnnotation(pin)
            }

            // Zoom to route if no active recording
            if recordedPoints.isEmpty {
                zoomToFit(map: map, coordinates: route.trackPoints)
            }
        }

        // Draw live recorded track (blue)
        if recordedPoints.count > 1 {
            let livePolyline = MKPolyline(coordinates: recordedPoints, count: recordedPoints.count)
            livePolyline.title = "live_track"
            map.addOverlay(livePolyline, level: .aboveRoads)
        }

        // Follow user while riding
        if followUser {
            map.userTrackingMode = .followWithHeading
        }
    }

    private func zoomToFit(map: MKMapView, coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }
        var minLat = coordinates[0].latitude,  maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude, maxLon = coordinates[0].longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude);  maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        map.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            if polyline.title == "live_track" {
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 4
            } else {
                renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.8)
                renderer.lineWidth = 3
                renderer.lineDashPattern = [8, 4]
            }
            return renderer
        }
    }
}

