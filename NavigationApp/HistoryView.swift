import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var routeStore: RouteStore

    var body: some View {
        NavigationStack {
            Group {
                if routeStore.rides.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        ForEach(routeStore.rides) { ride in
                            NavigationLink(destination: RideDetailView(ride: ride)) {
                                RideHistoryRow(ride: ride)
                            }
                        }
                        .onDelete { offsets in
                            routeStore.delete(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("My Rides")
            .toolbar {
                if !routeStore.rides.isEmpty {
                    EditButton()
                }
            }
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bicycle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No rides yet")
                .font(.title3.bold())
            Text("Start a ride or import a GPX to begin tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct RideHistoryRow: View {
    let ride: Ride

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ride.name)
                .font(.headline)
            Text(ride.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                RideStatBadge(icon: "arrow.triangle.swap", value: ride.formattedDistance)
                RideStatBadge(icon: "clock", value: ride.formattedDuration)
                RideStatBadge(icon: "speedometer", value: ride.formattedAvgSpeed)
                RideStatBadge(icon: "mountain.2", value: ride.formattedElevation)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RideStatBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(.secondary)
    }
}
