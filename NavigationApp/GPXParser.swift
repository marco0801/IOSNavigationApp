import Foundation
import CoreLocation

class GPXParser: NSObject, XMLParserDelegate {
    private var trackPoints: [CLLocationCoordinate2D] = []
    private var waypoints: [GPXWaypoint] = []
    private var routeName: String?
    private var currentElement = ""
    private var currentWaypoint: (coord: CLLocationCoordinate2D, name: String?)?
    private var isCapturingName = false
    private var capturedName = ""

    func parse(url: URL) -> GPXRoute? {
        // Reset state
        trackPoints = []
        waypoints = []
        routeName = nil
        currentElement = ""
        isCapturingName = false
        capturedName = ""

        guard let parser = XMLParser(contentsOf: url) else { return nil }
        parser.delegate = self
        let success = parser.parse()
        guard success else { return nil }

        let name = routeName ?? url.deletingPathExtension().lastPathComponent

        // Detect turns from track geometry
        let turns = NavigationEngine.detectTurns(in: trackPoints)

        return GPXRoute(
            name: name,
            trackPoints: trackPoints,
            waypoints: waypoints,
            turns: turns
        )
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        currentElement = elementName

        switch elementName {
        case "trkpt", "rtept":
            if let latStr = attributes["lat"], let lonStr = attributes["lon"],
               let lat = Double(latStr), let lon = Double(lonStr) {
                trackPoints.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        case "wpt":
            if let latStr = attributes["lat"], let lonStr = attributes["lon"],
               let lat = Double(latStr), let lon = Double(lonStr) {
                currentWaypoint = (CLLocationCoordinate2D(latitude: lat, longitude: lon), nil)
            }
        case "name":
            isCapturingName = true
            capturedName = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isCapturingName {
            capturedName += string
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        switch elementName {
        case "name":
            isCapturingName = false
            let trimmed = capturedName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if currentWaypoint != nil {
                    currentWaypoint?.name = trimmed
                } else if routeName == nil {
                    routeName = trimmed
                }
            }
        case "wpt":
            if let wpt = currentWaypoint {
                waypoints.append(GPXWaypoint(coordinate: wpt.coord, name: wpt.name))
                currentWaypoint = nil
            }
        default:
            break
        }
        if elementName == currentElement { currentElement = "" }
    }
}
