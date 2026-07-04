//
//  AbilityChip.swift
//  Pocket Dex
//
//  A tappable ability chip that loads and shows the ability's description in a popover.
//

import SwiftUI

struct AbilityChip: View {
    let ability: PokemonAbility

    @State private var showingInfo = false
    @State private var description: String?
    @State private var isLoading = false

    private var color: Color { Color.forAbility(ability.name) }

    var body: some View {
        Button {
            showingInfo = true
            Task { await loadDescription() }
        } label: {
            HStack(spacing: 4) {
                Text(ability.displayName)
                    .fontWeight(.medium)
                if ability.isHidden {
                    Image(systemName: "eye.slash")
                        .imageScale(.small)
                }
                Image(systemName: "info.circle")
                    .imageScale(.small)
                    .opacity(0.6)
            }
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ability.isHidden ? "\(ability.displayName), hidden ability" : ability.displayName)
        .popover(isPresented: $showingInfo) {
            abilityPopover
        }
    }

    private var abilityPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(ability.displayName)
                    .font(.headline)
                    .foregroundStyle(color)
                if ability.isHidden {
                    Text("Hidden")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2), in: Capsule())
                }
            }

            if isLoading {
                ProgressView()
            } else if let description {
                Text(description)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No description available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 320, alignment: .leading)
        .presentationCompactAdaptation(.popover)
    }

    private func loadDescription() async {
        guard description == nil else { return }
        isLoading = true
        description = try? await PokeAPIClient.shared.fetchAbilityDescription(named: ability.name)
        isLoading = false
    }
}
