//
//  Color+Pokemon.swift
//  Pocket Dex
//

import SwiftUI

extension Color {
    init(pokemonHex hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Canonical color for each Pokemon type, matching a standard type chart.
    static func pokemonType(_ type: String) -> Color {
        switch type.lowercased() {
        case "normal": Color(pokemonHex: 0xA8A77A)
        case "fire": Color(pokemonHex: 0xEE8130)
        case "water": Color(pokemonHex: 0x6390F0)
        case "electric": Color(pokemonHex: 0xF7D02C)
        case "grass": Color(pokemonHex: 0x7AC74C)
        case "ice": Color(pokemonHex: 0x96D9D6)
        case "fighting": Color(pokemonHex: 0xC22E28)
        case "poison": Color(pokemonHex: 0xA33EA1)
        case "ground": Color(pokemonHex: 0xE2BF65)
        case "flying": Color(pokemonHex: 0xA98FF3)
        case "psychic": Color(pokemonHex: 0xF95587)
        case "bug": Color(pokemonHex: 0xA6B91A)
        case "rock": Color(pokemonHex: 0xB6A136)
        case "ghost": Color(pokemonHex: 0x735797)
        case "dragon": Color(pokemonHex: 0x6F35FC)
        case "dark": Color(pokemonHex: 0x705746)
        case "steel": Color(pokemonHex: 0xB7B7CE)
        case "fairy": Color(pokemonHex: 0xD685AD)
        default: Color.gray
        }
    }

    /// A stable, distinct colour for an ability name (deterministic across launches).
    static func forAbility(_ name: String) -> Color {
        let palette: [Color] = [
            .blue, .green, .orange, .purple, .pink,
            .teal, .indigo, .red, .mint, .cyan, .brown
        ]
        let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFFFFFF }
        return palette[hash % palette.count]
    }
}
