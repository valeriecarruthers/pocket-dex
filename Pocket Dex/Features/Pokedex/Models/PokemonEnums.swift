//
//  PokemonEnums.swift
//  Pocket Dex
//
//  Filtering, sorting, region, and generation enums used across the Pokedex feature.
//

import SwiftUI

enum PokemonFormFilter: String, CaseIterable, Identifiable {
    case all
    case mega
    case gigantamax

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All Forms"
        case .mega: "Mega Evolution"
        case .gigantamax: "Gigantamax"
        }
    }

    func matches(_ pokemon: PokemonSummary) -> Bool {
        switch self {
        case .all: true
        case .mega: pokemon.hasMegaForm
        case .gigantamax: pokemon.hasGigantamaxForm
        }
    }
}

enum PokemonSortOption: String, CaseIterable, Identifiable {
    case pokedexNumber
    case name

    var id: Self { self }

    var title: String {
        switch self {
        case .pokedexNumber: "Pokedex Number"
        case .name: "Name"
        }
    }

    var systemImage: String {
        switch self {
        case .pokedexNumber: "number"
        case .name: "textformat.abc"
        }
    }
}

nonisolated enum PokemonRegion: String, CaseIterable, Identifiable {
    case all
    case kanto
    case johto
    case hoenn
    case sinnoh
    case unova
    case kalos
    case alola
    case galar
    case paldea

    var id: Self { self }

    var name: String {
        switch self {
        case .all: "All Regions"
        default: rawValue.capitalized
        }
    }

    var range: ClosedRange<Int>? {
        switch self {
        case .all: nil
        case .kanto: 1...151
        case .johto: 152...251
        case .hoenn: 252...386
        case .sinnoh: 387...493
        case .unova: 494...649
        case .kalos: 650...721
        case .alola: 722...809
        case .galar: 810...905
        case .paldea: 906...1025
        }
    }

    var numberRangeText: String? {
        guard let range else { return nil }
        return "\(range.lowerBound)–\(range.upperBound)"
    }

    // Short label for the fast-scroll index (distinct across regions, e.g. Kanto -> "Kan").
    var shortName: String {
        self == .all ? "All" : String(rawValue.prefix(3)).capitalized
    }

    func contains(_ pokedexNumber: Int) -> Bool {
        guard let range else { return true }
        return range.contains(pokedexNumber)
    }

    static func region(for pokedexNumber: Int) -> PokemonRegion {
        allCases.first { region in
            region != .all && region.contains(pokedexNumber)
        } ?? .all
    }
}

enum PokemonGeneration: Int, CaseIterable, Identifiable {
    case i = 1, ii, iii, iv, v, vi, vii, viii, ix

    var id: Int { rawValue }

    var title: String {
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]
        return "Generation \(numerals[rawValue - 1])"
    }

    var regionName: String {
        switch self {
        case .i: "Kanto"
        case .ii: "Johto"
        case .iii: "Hoenn"
        case .iv: "Sinnoh"
        case .v: "Unova"
        case .vi: "Kalos"
        case .vii: "Alola"
        case .viii: "Galar"
        case .ix: "Paldea"
        }
    }

    var color: Color {
        switch self {
        case .i: Color(pokemonHex: 0xE3350D)
        case .ii: Color(pokemonHex: 0xC9A227)
        case .iii: Color(pokemonHex: 0x00A651)
        case .iv: Color(pokemonHex: 0x2E86DE)
        case .v: Color(pokemonHex: 0x5D5D5D)
        case .vi: Color(pokemonHex: 0xE0559A)
        case .vii: Color(pokemonHex: 0xF0803C)
        case .viii: Color(pokemonHex: 0x7A5CC8)
        case .ix: Color(pokemonHex: 0x0E9594)
        }
    }

    // Groups games by the generation whose region they belong to, so remakes and region-linked
    // side games (Legends) sit with the original generation rather than their release year.
    static func forVersionGroup(_ name: String) -> PokemonGeneration? {
        switch name {
        case "red-blue", "yellow", "firered-leafgreen", "lets-go-pikachu-lets-go-eevee", "red-green-japan", "blue-japan":
            return .i
        case "gold-silver", "crystal", "heartgold-soulsilver":
            return .ii
        case "ruby-sapphire", "emerald", "omega-ruby-alpha-sapphire", "colosseum", "xd":
            return .iii
        case "diamond-pearl", "platinum", "brilliant-diamond-shining-pearl", "legends-arceus":
            return .iv
        case "black-white", "black-2-white-2":
            return .v
        case "x-y", "legends-za", "mega-dimension":
            return .vi
        case "sun-moon", "ultra-sun-ultra-moon":
            return .vii
        case "sword-shield", "the-isle-of-armor", "the-crown-tundra":
            return .viii
        case "scarlet-violet", "the-teal-mask", "the-indigo-disk":
            return .ix
        default:
            return nil
        }
    }
}
