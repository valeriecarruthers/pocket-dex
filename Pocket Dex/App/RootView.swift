//
//  RootView.swift
//  Pocket Dex
//
//  The app's top-level shell. For now it simply hosts the Pokedex; it will grow into the
//  bottom tab bar (Pokedex / Type Chart / Cards / Settings) as those features land.
//

import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        PokedexView()
    }
}

#Preview {
    RootView()
        .modelContainer(for: Item.self, inMemory: true)
}
