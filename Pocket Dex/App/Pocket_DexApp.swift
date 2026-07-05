//
//  Pocket_DexApp.swift
//  Pocket Dex
//
//  Created by Valerie Carruthers on 2026-07-01.
//

import SwiftUI
import SwiftData

@main
struct Pocket_DexApp: App {
    var sharedModelContainer: ModelContainer = {
        // The Pokedex "reference" store: public, re-fetchable data, so it's local-only (no iCloud).
        // The volatile TCG "market" store will join later as a second configuration
        // (CloudKit-synced for collections/wishlists) — hence the configurations array.
        let schema = Schema([SpeciesRecord.self, GameRecord.self, PokemonDetailRecord.self])
        let reference = ModelConfiguration("Reference", schema: schema, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [reference])
        } catch {
            // A schema change (e.g. the old template Item model → these records) can leave an
            // existing store unopenable. Rather than crash the app, wipe it and rebuild — safe
            // because everything here is re-fetchable reference data.
            try? FileManager.default.removeItem(at: reference.url)
            do {
                return try ModelContainer(for: schema, configurations: [reference])
            } catch {
                fatalError("Could not create ModelContainer even after resetting the store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
