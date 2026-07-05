//
//  PokedexRecords.swift
//  Pocket Dex
//
//  SwiftData models for the persistent "reference" store: the species list, the games
//  list, and per-Pokemon details. These are pure persistence types — the app's views keep
//  using the value-type models (PokemonSummary/PokemonGame/PokemonDetail), and we map
//  records to those structs at the boundary (see the extensions at the bottom).
//

import Foundation
import SwiftData

/// One entry in the national dex list — the backbone of the instant-loading gallery.
@Model
final class SpeciesRecord {
    @Attribute(.unique) var id: Int
    var name: String
    var url: URL

    init(id: Int, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }
}

/// One playable game (PokeAPI version group), cached for the game filter and appearances.
@Model
final class GameRecord {
    @Attribute(.unique) var id: Int
    var name: String
    var url: URL

    init(id: Int, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }
}

/// A Pokemon's full detail, fetched lazily the first time it's opened and kept forever.
///
/// The nested value types (evolution tree, forms, default form) are persisted as JSON `Data`
/// blobs rather than native SwiftData attributes: SwiftData's built-in Codable-attribute
/// encoder asserts on these nested/recursive value types (EvolutionNode is self-referential),
/// so we own the (de)serialization and expose the decoded values via computed accessors.
@Model
final class PokemonDetailRecord {
    @Attribute(.unique) var id: Int
    var pokedexNames: [String]
    var flavorText: String?
    var genus: String?
    var habitat: String?
    // Resolved lazily; caches the app's heaviest call (fetchGamesForSpecies) so revisits are offline.
    var gameAppearanceIDs: [Int]?
    var fetchedAt: Date

    private var evolutionTreeData: Data
    private var formsData: Data
    private var defaultFormData: Data

    var evolutionTree: [EvolutionNode] {
        get { (try? JSONDecoder().decode([EvolutionNode].self, from: evolutionTreeData)) ?? [] }
        set { evolutionTreeData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var forms: [PokemonForm] {
        get { (try? JSONDecoder().decode([PokemonForm].self, from: formsData)) ?? [] }
        set { formsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var defaultForm: PokemonFormDetail {
        get {
            (try? JSONDecoder().decode(PokemonFormDetail.self, from: defaultFormData))
                ?? PokemonFormDetail(regularImageURL: nil, shinyImageURL: nil, types: [], abilities: [], height: 0, weight: 0, baseExperience: nil)
        }
        set { defaultFormData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init(
        id: Int,
        pokedexNames: [String] = [],
        flavorText: String? = nil,
        genus: String? = nil,
        habitat: String? = nil,
        evolutionTree: [EvolutionNode] = [],
        forms: [PokemonForm] = [],
        defaultForm: PokemonFormDetail,
        gameAppearanceIDs: [Int]? = nil,
        fetchedAt: Date = .now
    ) {
        self.id = id
        self.pokedexNames = pokedexNames
        self.flavorText = flavorText
        self.genus = genus
        self.habitat = habitat
        self.gameAppearanceIDs = gameAppearanceIDs
        self.fetchedAt = fetchedAt
        self.evolutionTreeData = (try? JSONEncoder().encode(evolutionTree)) ?? Data()
        self.formsData = (try? JSONEncoder().encode(forms)) ?? Data()
        self.defaultFormData = (try? JSONEncoder().encode(defaultForm)) ?? Data()
    }

    /// Copies a freshly fetched detail into this record (used for both insert and update upserts).
    func apply(_ detail: PokemonDetail, gameAppearanceIDs: [Int]?) {
        pokedexNames = detail.pokedexNames
        flavorText = detail.flavorText
        genus = detail.genus
        habitat = detail.habitat
        evolutionTree = detail.evolutionTree
        forms = detail.forms
        defaultForm = detail.defaultForm
        if let gameAppearanceIDs { self.gameAppearanceIDs = gameAppearanceIDs }
        fetchedAt = .now
    }
}

// MARK: - Record → value-type mappers

extension PokemonSummary {
    nonisolated init(_ record: SpeciesRecord) {
        self.init(id: record.id, name: record.name, url: record.url)
    }
}

extension PokemonGame {
    nonisolated init(_ record: GameRecord) {
        self.init(id: record.id, name: record.name, url: record.url)
    }
}

extension PokemonDetail {
    nonisolated init(_ record: PokemonDetailRecord, summary: PokemonSummary) {
        self.init(
            summary: summary,
            pokedexNames: record.pokedexNames,
            flavorText: record.flavorText,
            genus: record.genus,
            habitat: record.habitat,
            evolutionTree: record.evolutionTree,
            forms: record.forms,
            defaultForm: record.defaultForm
        )
    }
}
