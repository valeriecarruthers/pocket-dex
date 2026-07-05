//
//  TypeBadge.swift
//  Pocket Dex
//
//  A single coloured type capsule, matching the style used by TypeChips elsewhere.
//

import SwiftUI

struct TypeBadge: View {
    let type: PokemonType

    var body: some View {
        Text(type.displayName)
            .typeCapsule(type.color)
    }
}

#Preview {
    TypeBadge(type: .fire)
}
