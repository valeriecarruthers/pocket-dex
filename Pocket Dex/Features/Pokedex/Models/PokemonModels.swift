//
//  PokemonModels.swift
//  Pocket Dex
//
//  Value types describing a Pokemon and its details, decoded from PokeAPI responses.
//

import Foundation

nonisolated struct PokemonSummary: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let url: URL

    var pokedexNumber: Int { id }

    var displayName: String {
        name.displayName
    }

    var formattedPokedexNumber: String {
        "#" + String(format: "%04d", pokedexNumber)
    }

    var region: PokemonRegion {
        PokemonRegion.region(for: pokedexNumber)
    }

    private static let spriteBase = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"

    // High-quality official artwork used as the final gallery/detail image.
    var artworkURL: URL? {
        URL(string: "\(Self.spriteBase)/other/official-artwork/\(id).png")
    }

    var shinyArtworkURL: URL? {
        URL(string: "\(Self.spriteBase)/other/official-artwork/shiny/\(id).png")
    }

    // Tiny (~1 KB) pixel sprites used as an instant low-res preview while the artwork loads.
    var spriteURL: URL? {
        URL(string: "\(Self.spriteBase)/\(id).png")
    }

    var shinySpriteURL: URL? {
        URL(string: "\(Self.spriteBase)/shiny/\(id).png")
    }

    // Whether this species has alternate forms/varieties (regional, Mega, battle forms, etc.).
    var hasAlternateForms: Bool {
        Self.speciesWithForms.contains(id)
    }

    var hasMegaForm: Bool { Self.megaSpecies.contains(id) }
    var hasGigantamaxForm: Bool { Self.gigantamaxSpecies.contains(id) }

    // Species (by national dex number) with a Mega Evolution. Generated from PokeAPI.
    private static let megaSpecies: Set<Int> = [
        3, 6, 9, 15, 18, 26, 36, 65, 71, 80, 94, 115, 121, 127, 130, 142, 149, 150, 154, 160,
        181, 208, 212, 214, 227, 229, 248, 254, 257, 260, 282, 302, 303, 306, 308, 310, 319,
        323, 334, 354, 358, 359, 362, 373, 376, 380, 381, 384, 398, 428, 445, 448, 460, 475,
        478, 485, 491, 500, 530, 531, 545, 560, 604, 609, 623, 652, 655, 658, 668, 670, 678,
        687, 689, 691, 701, 718, 719, 740, 768, 780, 801, 807, 870, 952, 970, 978, 998
    ]

    // Species (by national dex number) with a Gigantamax form. Generated from PokeAPI.
    private static let gigantamaxSpecies: Set<Int> = [
        3, 6, 9, 12, 25, 52, 68, 94, 99, 131, 133, 143, 569, 809, 812, 815, 818, 823, 826,
        834, 839, 841, 842, 844, 849, 851, 858, 861, 869, 879, 884, 892
    ]

    // Species (by national dex number) that have more than one variety. Generated from PokeAPI.
    private static let speciesWithForms: Set<Int> = [
        3, 6, 9, 12, 15, 18, 19, 20, 25, 26, 27, 28, 36, 37, 38, 50, 51, 52, 53, 58, 59, 65,
        68, 71, 74, 75, 76, 77, 78, 79, 80, 83, 88, 89, 94, 99, 100, 101, 103, 105, 110, 115,
        121, 122, 127, 128, 130, 131, 133, 142, 143, 144, 145, 146, 149, 150, 154, 157, 160,
        181, 194, 199, 208, 211, 212, 214, 215, 222, 227, 229, 248, 254, 257, 260, 263, 264,
        282, 302, 303, 306, 308, 310, 319, 323, 334, 351, 354, 358, 359, 362, 373, 376, 380,
        381, 382, 383, 384, 386, 398, 413, 428, 445, 448, 460, 475, 478, 479, 483, 484, 485,
        487, 491, 492, 500, 503, 530, 531, 545, 549, 550, 554, 555, 560, 562, 569, 570, 571,
        604, 609, 618, 623, 628, 641, 642, 645, 646, 647, 648, 652, 655, 658, 668, 670, 678,
        681, 687, 689, 691, 701, 705, 706, 710, 711, 713, 718, 719, 720, 724, 735, 738, 740,
        741, 743, 744, 745, 746, 752, 754, 758, 768, 774, 777, 778, 780, 784, 800, 801, 807,
        809, 812, 815, 818, 823, 826, 834, 839, 841, 842, 844, 845, 849, 851, 858, 861, 869,
        870, 875, 876, 877, 879, 884, 888, 889, 890, 892, 893, 898, 901, 902, 905, 916, 925,
        931, 952, 964, 970, 978, 982, 998, 999, 1007, 1008, 1017, 1024
    ]
}

/// A playable game, modelled on PokeAPI's version groups (e.g. "scarlet-violet").
nonisolated struct PokemonGame: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let url: URL

    var displayName: String {
        switch name {
        case "red-blue": "Red & Blue"
        case "gold-silver": "Gold & Silver"
        case "ruby-sapphire": "Ruby & Sapphire"
        case "firered-leafgreen": "FireRed & LeafGreen"
        case "diamond-pearl": "Diamond & Pearl"
        case "heartgold-soulsilver": "HeartGold & SoulSilver"
        case "black-white": "Black & White"
        case "black-2-white-2": "Black 2 & White 2"
        case "x-y": "X & Y"
        case "omega-ruby-alpha-sapphire": "Omega Ruby & Alpha Sapphire"
        case "sun-moon": "Sun & Moon"
        case "ultra-sun-ultra-moon": "Ultra Sun & Ultra Moon"
        case "lets-go-pikachu-lets-go-eevee": "Let's Go Pikachu & Eevee"
        case "sword-shield": "Sword & Shield"
        case "brilliant-diamond-shining-pearl": "Brilliant Diamond & Shining Pearl"
        case "legends-arceus": "Legends: Arceus"
        case "scarlet-violet": "Scarlet & Violet"
        case "legends-za": "Legends: Z-A"
        case "the-isle-of-armor": "The Isle of Armor"
        case "the-crown-tundra": "The Crown Tundra"
        case "the-teal-mask": "The Teal Mask"
        case "the-indigo-disk": "The Indigo Disk"
        case "red-green-japan": "Red & Green"
        case "blue-japan": "Blue (JP)"
        case "mega-dimension": "Mega Dimension"
        default: name.displayName
        }
    }
}

nonisolated struct PokemonAbility: Hashable, Codable, Sendable {
    let name: String
    let isHidden: Bool

    var displayName: String { name.displayName }
}

nonisolated struct PokemonDetail: Sendable {
    let summary: PokemonSummary
    let pokedexNames: [String]
    let flavorText: String?
    let genus: String?
    let habitat: String?
    let evolutionTree: [EvolutionNode]
    let forms: [PokemonForm]
    let defaultForm: PokemonFormDetail
}

// A single form/variety (e.g. Galarian Zapdos, Lycanroc Dusk).
nonisolated struct PokemonForm: Identifiable, Hashable, Codable, Sendable {
    let name: String
    let url: URL
    let isDefault: Bool
    let label: String

    var id: String { name }
}

// The form-specific data that changes when switching forms.
nonisolated struct PokemonFormDetail: Codable, Sendable {
    let regularImageURL: URL?
    let shinyImageURL: URL?
    let types: [String]
    let abilities: [PokemonAbility]
    let height: Int
    let weight: Int
    let baseExperience: Int?

    var heightText: String {
        String(format: "%.1f m", Double(height) / 10.0)
    }

    var weightText: String {
        String(format: "%.1f kg", Double(weight) / 10.0)
    }

    var baseExperienceText: String {
        baseExperience.map(String.init) ?? "Unknown"
    }
}

nonisolated struct EvolutionNode: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
    let requirement: String?
    let children: [EvolutionNode]

    var displayName: String { name.displayName }

    var formattedPokedexNumber: String {
        "#" + String(format: "%04d", id)
    }

    var spriteURL: URL? {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id).png")
    }
}
