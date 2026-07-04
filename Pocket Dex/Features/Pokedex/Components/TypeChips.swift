//
//  TypeChips.swift
//  Pocket Dex
//
//  A wrapping row of coloured Pokemon type chips.
//

import SwiftUI

struct TypeChips: View {
    let types: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(types, id: \.self) { type in
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.pokemonType(type), in: Capsule())
            }
        }
    }
}
