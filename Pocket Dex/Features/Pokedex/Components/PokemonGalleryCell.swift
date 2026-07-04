//
//  PokemonGalleryCell.swift
//  Pocket Dex
//
//  A single Pokemon tile in the gallery grid.
//

import SwiftUI

struct PokemonGalleryCell: View {
    let pokemon: PokemonSummary
    let showingShiny: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            PokemonArtworkView(
                url: showingShiny ? pokemon.shinyArtworkURL : pokemon.artworkURL,
                lowResURL: showingShiny ? pokemon.shinySpriteURL : pokemon.spriteURL,
                title: pokemon.displayName
            )
            .frame(height: 120)
            .overlay(alignment: .topTrailing) {
                if pokemon.hasAlternateForms {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.tint, in: Circle())
                        .padding(4)
                        .accessibilityLabel("Has alternate forms")
                }
            }

            Text(pokemon.displayName)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(pokemon.formattedPokedexNumber)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(isSelected ? 0.9 : 0.35), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.tint, lineWidth: isSelected ? 3 : 0)
        }
    }
}
