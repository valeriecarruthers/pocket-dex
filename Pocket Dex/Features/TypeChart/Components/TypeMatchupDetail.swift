//
//  TypeMatchupDetail.swift
//  Pocket Dex
//
//  A single type's full matchup breakdown: how it fares on offence (the damage it deals)
//  and on defence (the damage it takes). Empty categories are omitted so the layout stays
//  tight for types with few matchups.
//

import SwiftUI

struct TypeMatchupDetail: View {
    let type: PokemonType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                section(
                    "When Attacking",
                    rows: [
                        ("Super effective", "2×", type.superEffectiveAgainst),
                        ("Not very effective", "½×", type.notVeryEffectiveAgainst),
                        ("No effect", "0×", type.noEffectAgainst)
                    ]
                )

                section(
                    "When Defending",
                    rows: [
                        ("Weak to", "2×", type.weakTo),
                        ("Resists", "½×", type.resists),
                        ("Immune to", "0×", type.immuneTo)
                    ]
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(type.color)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(type.abbreviation)
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            Text(type.displayName)
                .font(.largeTitle).fontWeight(.bold)
        }
    }

    // A titled block ("When Attacking") containing one row per non-empty matchup category.
    private func section(_ title: String, rows: [(String, String, [PokemonType])]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(rows.filter { !$0.2.isEmpty }, id: \.0) { label, multiplier, types in
                matchupRow(label: label, multiplier: multiplier, types: types)
            }
        }
    }

    private func matchupRow(label: String, multiplier: String, types: [PokemonType]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(multiplier)
                    .font(.subheadline).fontWeight(.bold)
                    .monospacedDigit()
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 8) {
                ForEach(types) { TypeBadge(type: $0) }
            }
            // FlowLayout uses an HStack when its content fits on one line, which otherwise
            // reads as centered; pinning to full-width leading keeps every row consistent.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    TypeMatchupDetail(type: .ghost)
}
