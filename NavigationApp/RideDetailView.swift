import SwiftUI
import MapKit
import Charts

struct RideDetailView: View {
    let ride: Ride
    @EnvironmentObject var routeStore: RouteStore

    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var isRenaming = false
    @State private var newName = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Map ──
                RideMapReplay(trackPoints: ride.trackPoints.map(\.coordinate))
                    .frame(height: 280)
                    .clipShape(Rectangle())

                // ── Stats Grid ──
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 1) {
                    DetailStatCell(label: "Distance",     value: ride.formattedDistance,  icon: "arrow.triangle.swap")
                    DetailStatCell(label: "Duration",     value: ride.formattedDuration,  icon: "clock")
                    DetailStatCell(label: "Avg Speed",    value: ride.formattedAvgSpeed,  icon: "speedometer")
                    DetailStatCell(label: "Max Speed",    value: ride.formattedMaxSpeed,  icon: "gauge.with.dots.needle.100percent")
                    DetailStatCell(label: "Elev. Gain",   value: ride.formattedElevation, icon: "mountain.2")
                    DetailStatCell(label: "Date",
                                   value: ride.date.formatted(date: .abbreviated, time: .shortened),
                                   icon: "calendar")
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()

                // ── Elevation Profile ──
                if ride.trackPoints.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Elevation Profile")
                            .font(.headline)
                            .padding(.horizontal)

                        ElevationChart(trackPoints: ride.trackPoints)
                            .frame(height: 160)
                            .padding(.horizontal)
                    }
                    .padding(.bottom)
                }

                // ── Export ──
                Button {
                    exportGPX()
                } label: {
                    Label("Export GPX", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(ride.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newName = ride.name
                        isRenaming = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        routeStore.delete(ride: ride)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Ride", isPresented: $isRenaming) {
            TextField("Ride name", text: $newName)
            Button("Save") { routeStore.rename(ride: ride, to: newName) }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportGPX() {
        guard let url = GPXExporter.export(ride: ride) else { return }
        exportURL = url
        showShareSheet = true
    }
}

// MARK: - Detail Stat Cell

struct DetailStatCell: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground))
    }
}

// MARK: - Map Replay

struct RideMapReplay: UIViewRepresentable {
    let trackPoints: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isPitchEnabled = false
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        guard !trackPoints.isEmpty else { return }

        let polyline = MKPolyline(coordinates: trackPoints, count: trackPoints.count)
        map.addOverlay(polyline, level: .aboveRoads)

        // Add start/end pins
        let startPin = MKPointAnnotation()
        startPin.coordinate = trackPoints.first!
        startPin.title = "Start"

        let endPin = MKPointAnnotation()
        endPin.coordinate = trackPoints.last!
        endPin.title = "Finish"

        map.addAnnotations([startPin, endPin])

        var minLat = trackPoints[0].latitude,  maxLat = trackPoints[0].latitude
        var minLon = trackPoints[0].longitude, maxLon = trackPoints[0].longitude
        for c in trackPoints {
            minLat = min(minLat, c.latitude);  maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let region = MKCoordinateRegion(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span:   .init(latitudeDelta: (maxLat - minLat) * 1.4, longitudeDelta: (maxLon - minLon) * 1.4)
        )
        map.setRegion(region, animated: false)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = UIColor.systemBlue
                r.lineWidth = 3
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Elevation Chart

struct ElevationChart: View {
    let trackPoints: [TrackPoint]

    var samples: [(index: Int, altitude: Double)] {
        // Downsample to max 200 points for performance
        let step = max(1, trackPoints.count / 200)
        return stride(from: 0, to: trackPoints.count, by: step).map { i in
            (index: i, altitude: trackPoints[i].altitude)
        }
    }

    var minAlt: Double { samples.map(\.altitude).min() ?? 0 }
    var maxAlt: Double { samples.map(\.altitude).max() ?? 100 }

    var body: some View {
        Chart(samples, id: \.index) { point in
            AreaMark(
                x: .value("Point", point.index),
                yStart: .value("Min", minAlt),
                yEnd: .value("Altitude", point.altitude)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue.opacity(0.6), .blue.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            LineMark(
                x: .value("Point", point.index),
                y: .value("Altitude", point.altitude)
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))m").font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartYScale(domain: (minAlt - 5)...(maxAlt + 5))
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
