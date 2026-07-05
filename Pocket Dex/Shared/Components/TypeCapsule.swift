//
//  TypeCapsule.swift
//  Pocket Dex
//
//  The shared visual style for a Pokemon-type "chip": white semibold caption text on a
//  coloured Capsule. Used by both TypeChips (Pokédex) and TypeBadge (Type Chart) so the two
//  can never drift apart.
//

import SwiftUI

extension View {
    /// Styles the receiver (typically a type-name `Text`) as a coloured type capsule.
    func typeCapsule(_ color: Color) -> some View {
        self
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color, in: Capsule())
    }
}
