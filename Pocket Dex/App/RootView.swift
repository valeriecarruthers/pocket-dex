//
//  RootView.swift
//  Pocket Dex
//
//  The app's top-level shell: a bottom tab bar hosting each top-level feature. The Pokedex,
//  Type Chart, and Settings tabs exist today; Cards will join as it lands.
//

import SwiftUI
import SwiftData

struct RootView: View {
    // The set of top-level tabs. Using an enum as the TabView's selection value keeps tab
    // state explicit and easy to drive programmatically (and to assert against in UI tests).
    // Named AppTab to avoid shadowing SwiftUI's own `Tab` type used below.
    enum AppTab: Hashable {
        case pokedex
        case typeChart
        case settings
    }

    @State private var selectedTab: AppTab = .pokedex

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Pokédex", systemImage: "square.grid.2x2", value: AppTab.pokedex) {
                PokedexView()
            }

            Tab("Type Chart", systemImage: "tablecells", value: AppTab.typeChart) {
                TypeChartView()
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
