import Foundation

class GPXExporter {

    static func export(ride: Ride) -> URL? {
        let gpx = buildGPX(ride: ride)
        let filename = sanitize(ride.name) + ".gpx"

        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(filename)

        do {
            try gpx.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("GPX export error: \(error)")
            return nil
        }
    }

    private static func buildGPX(ride: Ride) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1"
             creator="BikeNav"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escapeXML(ride.name))</name>
            <time>\(formatter.string(from: ride.date))</time>
          </metadata>
          <trk>
            <name>\(escapeXML(ride.name))</name>
            <trkseg>
        """

        for point in ride.trackPoints {
            let lat = String(format: "%.7f", point.latitude)
            let lon = String(format: "%.7f", point.longitude)
            let ele = String(format: "%.1f", point.altitude)
            let time = formatter.string(from: point.timestamp)
            xml += """
                  <trkpt lat="\(lat)" lon="\(lon)">
                    <ele>\(ele)</ele>
                    <time>\(time)</time>
                  </trkpt>
            """
        }

        xml += """

            </trkseg>
          </trk>
        </gpx>
        """

        return xml
    }

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_ "))
        return name.components(separatedBy: allowed.inverted).joined(separator: "_")
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
