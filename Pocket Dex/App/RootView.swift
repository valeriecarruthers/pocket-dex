//
//  RootView.swift
//  Pocket Dex
//
//  The app's top-level shell: a bottom tab bar hosting each top-level feature. Only the
//  Pokedex and Settings tabs exist today; Type Chart and Cards will join as they land.
//

import SwiftUI
import SwiftData

struct RootView: View {
    // The set of top-level tabs. Using an enum as the TabView's selection value keeps tab
    // state explicit and easy to drive programmatically (and to assert against in UI tests).
    // Named AppTab to avoid shadowing SwiftUI's own `Tab` type used below.
    enum AppTab: Hashable {
        case pokedex
        case settings
    }

    @State private var selectedTab: AppTab = .pokedex

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Pokédex", systemImage: "square.grid.2x2", value: AppTab.pokedex) {
                PokedexView()
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Item.self, inMemory: true)
}
