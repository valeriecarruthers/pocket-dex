//
//  PokemonType.swift
//  Pocket Dex
//
//  The 18 Pokemon types and the canonical (Gen 6+) type-effectiveness chart.
//
//  The chart is expressed once, from the attacker's point of view: each type lists the
//  defenders it hits for 2×, ½×, and 0× damage. Everything else — including the defensive
//  view (what a type is weak/resistant/immune to) — is derived from those three lists, so
//  there is a single source of truth to keep correct.
//

import SwiftUI

enum PokemonType: String, CaseIterable, Identifiable {
    // Declared in canonical type-chart order so grids and pickers read naturally.
    case normal, fire, water, electric, grass, ice, fighting, poison
    case ground, flying, psychic, bug, rock, ghost, dragon, dark, steel, fairy

    var id: Self { self }

    /// "Fire", "Fighting", etc. Reuses the shared String formatter for consistency.
    var displayName: String { rawValue.displayName }

    /// The canonical type colour, shared with the rest of the app (chips, badges).
    var color: Color { .pokemonType(rawValue) }

    /// A distinct three-letter label for dense grid headers ("Fir", "Fig", "Fly", …).
    /// A plain 3-character prefix happens to be unique across all 18 type names.
    var abbreviation: String { String(rawValue.prefix(3)).capitalized }

    // MARK: - Offensive chart (attacker → defenders)

    /// Defenders this type deals 2× damage to when attacking.
    var superEffectiveAgainst: [PokemonType] {
        switch self {
        case .normal: []
        case .fire: [.grass, .ice, .bug, .steel]
        case .water: [.fire, .ground, .rock]
        case .electric: [.water, .flying]
        case .grass: [.water, .ground, .rock]
        case .ice: [.grass, .ground, .flying, .dragon]
        case .fighting: [.normal, .ice, .rock, .dark, .steel]
        case .poison: [.grass, .fairy]
        case .ground: [.fire, .electric, .poison, .rock, .steel]
        case .flying: [.grass, .fighting, .bug]
        case .psychic: [.fighting, .poison]
        case .bug: [.grass, .psychic, .dark]
        case .rock: [.fire, .ice, .flying, .bug]
        case .ghost: [.psychic, .ghost]
        case .dragon: [.dragon]
        case .dark: [.psychic, .ghost]
        case .steel: [.ice, .rock, .fairy]
        case .fairy: [.fighting, .dragon, .dark]
        }
    }

    /// Defenders this type deals ½× damage to when attacking.
    var notVeryEffectiveAgainst: [PokemonType] {
        switch self {
        case .normal: [.rock, .steel]
        case .fire: [.fire, .water, .rock, .dragon]
        case .water: [.water, .grass, .dragon]
        case .electric: [.electric, .grass, .dragon]
        case .grass: [.fire, .grass, .poison, .flying, .bug, .dragon, .steel]
        case .ice: [.fire, .water, .ice, .steel]
        case .fighting: [.poison, .flying, .psychic, .bug, .fairy]
        case .poison: [.poison, .ground, .rock, .ghost]
        case .ground: [.grass, .bug]
        case .flying: [.electric, .rock, .steel]
        case .psychic: [.psychic, .steel]
        case .bug: [.fire, .fighting, .poison, .flying, .ghost, .steel, .fairy]
        case .rock: [.fighting, .ground, .steel]
        case .ghost: [.dark]
        case .dragon: [.steel]
        case .dark: [.fighting, .dark, .fairy]
        case .steel: [.fire, .water, .electric, .steel]
        case .fairy: [.fire, .poison, .steel]
        }
    }

    /// Defenders this type deals no damage to (immune when attacking).
    var noEffectAgainst: [PokemonType] {
        switch self {
        case .normal: [.ghost]
        case .electric: [.ground]
        case .fighting: [.ghost]
        case .poison: [.steel]
        case .ground: [.flying]
        case .psychic: [.dark]
        case .ghost: [.normal]
        case .dragon: [.fairy]
        default: []
        }
    }

    // MARK: - Derived lookups

    /// Damage multiplier this type deals to `defender` when attacking (0, 0.5, 1, or 2).
    func attackMultiplier(against defender: PokemonType) -> Double {
        if noEffectAgainst.contains(defender) { return 0 }
        if superEffectiveAgainst.contains(defender) { return 2 }
        if notVeryEffectiveAgainst.contains(defender) { return 0.5 }
        return 1
    }

    /// Types that hit this type for 2× when it is defending.
    var weakTo: [PokemonType] {
        Self.allCases.filter { $0.attackMultiplier(against: self) == 2 }
    }

    /// Types this type resists (takes ½× from) when defending.
    var resists: [PokemonType] {
        Self.allCases.filter { $0.attackMultiplier(against: self) == 0.5 }
    }

    /// Types this type is immune to (takes 0× from) when defending.
    var immuneTo: [PokemonType] {
        Self.allCases.filter { $0.attackMultiplier(against: self) == 0 }
    }
}

extension PokemonType {
    /// A compact label for a type-chart multiplier ("0", "½", "1", "2"). Scoped here rather
    /// than as a global Double extension so it stays tied to type effectiveness.
    static func effectivenessLabel(_ multiplier: Double) -> String {
        switch multiplier {
        case 0: "0"
        case 0.5: "½"
        case 2: "2"
        default: "1"
        }
    }
}
