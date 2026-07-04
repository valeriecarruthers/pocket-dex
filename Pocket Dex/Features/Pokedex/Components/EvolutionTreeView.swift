//
//  EvolutionTreeView.swift
//  Pocket Dex
//
//  Renders a species' evolution chain as an indented, tappable tree.
//

import SwiftUI

struct EvolutionTreeView: View {
    let nodes: [EvolutionNode]
    let selectPokemonID: (Int) -> Void

    var body: some View {
        DetailSection(title: "Evolution") {
            if nodes.isEmpty {
                Text("No evolution data returned by PokeAPI.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(nodes) { node in
                        EvolutionNodeView(node: node, level: 0, selectPokemonID: selectPokemonID)
                    }
                }
            }
        }
    }
}

private struct EvolutionNodeView: View {
    let node: EvolutionNode
    let level: Int
    let selectPokemonID: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                selectPokemonID(node.id)
            } label: {
                HStack(spacing: 12) {
                    PokemonArtworkView(url: node.spriteURL, title: node.displayName)
                        .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(node.displayName)
                            .font(.headline)
                        Text(node.formattedPokedexNumber)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if let requirement = node.requirement {
                            Text(requirement)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(node.id <= 0)
            .padding(.leading, CGFloat(level) * 20)

            ForEach(node.children) { child in
                EvolutionNodeView(node: child, level: level + 1, selectPokemonID: selectPokemonID)
            }
        }
    }
}
