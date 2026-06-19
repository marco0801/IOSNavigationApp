import SwiftUI
import UniformTypeIdentifiers

struct ExploreView: View {
    @Binding var activeRoute: GPXRoute?
    @Binding var selectedTab: Int

    @State private var isPickerPresented = false
    @State private var parseError: String?
    @State private var showError = false
    @State private var importedRoutes: [GPXRoute] = []

    var body: some View {
        NavigationStack {
            List {
                // ── Import Section ──
                Section {
                    Button {
                        isPickerPresented = true
                    } label: {
                        Label("Import GPX File", systemImage: "doc.badge.plus")
                            .font(.headline)
                    }
                } header: {
                    Text("New Route")
                }

                // ── Loaded Routes ──
                if !importedRoutes.isEmpty {
                    Section {
                        ForEach(importedRoutes) { route in
                            RouteRow(route: route) {
                                activeRoute = route
                                selectedTab = 1 // switch to Ride tab
                            }
                        }
                        .onDelete { offsets in
                            importedRoutes.remove(atOffsets: offsets)
                            if importedRoutes.isEmpty { activeRoute = nil }
                        }
                    } header: {
                        Text("Imported Routes")
                    }
                }

                // ── Empty State ──
                if importedRoutes.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "map")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Import a GPX file to navigate a route,\nor head to the Ride tab to record a new ride.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Explore")
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(parseError ?? "Could not read GPX file.")
            }
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                parseError = "Permission denied."
                showError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let parser = GPXParser()
            if let route = parser.parse(url: url) {
                importedRoutes.insert(route, at: 0)
                activeRoute = route
            } else {
                parseError = "Could not parse this GPX file. Make sure it contains a valid track."
                showError = true
            }

        case .failure(let error):
            parseError = error.localizedDescription
            showError = true
        }
    }
}

struct RouteRow: View {
    let route: GPXRoute
    let onStart: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    Label(
                        String(format: "%.1f km", route.totalDistance / 1000),
                        systemImage: "arrow.triangle.swap"
                    )
                    Label(
                        "\(route.turns.count) turns",
                        systemImage: "arrow.turn.up.right"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onStart()
            } label: {
                Text("Navigate")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
