import Foundation
import Combine
import SwiftUI

class RouteStore: ObservableObject {
    @Published var rides: [Ride] = []

    private let filename = "saved_rides.json"

    private var storageURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    init() {
        load()
    }

    // MARK: - CRUD

    func save(ride: Ride) {
        rides.insert(ride, at: 0) // newest first
        persist()
    }

    func delete(at offsets: IndexSet) {
        rides.remove(atOffsets: offsets)
        persist()
    }

    func delete(ride: Ride) {
        rides.removeAll { $0.id == ride.id }
        persist()
    }

    func rename(ride: Ride, to newName: String) {
        guard let index = rides.firstIndex(where: { $0.id == ride.id }) else { return }
        rides[index].name = newName
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(rides)
            try data.write(to: storageURL, options: .atomicWrite)
        } catch {
            print("RouteStore save error: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            rides = try JSONDecoder().decode([Ride].self, from: data)
        } catch {
            print("RouteStore load error: \(error)")
        }
    }
}
