//
//  ShinyToggleButton.swift
//  Pocket Dex
//
//  Toolbar button that toggles between regular and shiny artwork.
//

import SwiftUI

struct ShinyToggleButton: View {
    @Binding var showingShiny: Bool

    var body: some View {
        Button {
            showingShiny.toggle()
        } label: {
            Label("Shiny", systemImage: showingShiny ? "sparkles.rectangle.stack.fill" : "sparkles")
        }
        .tint(showingShiny ? .yellow : nil)
        .help(showingShiny ? "Show regular artwork" : "Show shiny artwork")
    }
}
