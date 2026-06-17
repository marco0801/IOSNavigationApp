//
//  NavigationAppApp.swift
//  NavigationApp
//
//  Created by Marc-Olivier Bergeron on 2026-06-17.
//

import SwiftUI
import CoreData

@main
struct NavigationAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
