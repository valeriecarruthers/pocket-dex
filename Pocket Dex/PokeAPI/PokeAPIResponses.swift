//
//  PokeAPIResponses.swift
//  Pocket Dex
//
//  Decodable DTOs mirroring the PokeAPI (pokeapi.co) JSON payloads.
//

import Foundation

struct PokeAPIResourceList: Decodable {
    let results: [PokeAPIResource]
}

struct PokeAPIURLReference: Decodable {
    let url: URL
}

struct PokeAPIResource: Decodable, Hashable {
    let name: String
    let url: URL

    var id: Int? {
        url.pathComponents
            .last { component in Int(component) != nil }
            .flatMap(Int.init)
    }
}

struct PokeAPIVersionGroupResponse: Decodable {
    let pokedexes: [PokeAPIResource]
}

struct PokeAPIPokedexResponse: Decodable {
    let pokemonEntries: [PokeAPIPokedexEntry]

    enum CodingKeys: String, CodingKey {
        case pokemonEntries = "pokemon_entries"
    }
}

struct PokeAPIPokedexEntry: Decodable {
    let pokemonSpecies: PokeAPIResource

    enum CodingKeys: String, CodingKey {
        case pokemonSpecies = "pokemon_species"
    }
}

struct PokeAPIPokemonResponse: Decodable {
    let id: Int
    let name: String
    let height: Int
    let weight: Int
    let baseExperience: Int?
    let sprites: PokeAPISprites
    let types: [PokeAPITypeSlot]
    let abilities: [PokeAPIAbilitySlot]
    let gameIndices: [PokeAPIGameIndex]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case height
        case weight
        case baseExperience = "base_experience"
        case sprites
        case types
        case abilities
        case gameIndices = "game_indices"
    }
}

struct PokeAPISprites: Decodable {
    let frontDefault: URL?
    let frontShiny: URL?
    let other: PokeAPIOtherSprites?

    var bestRegularURL: URL? {
        other?.officialArtwork.frontDefault ?? frontDefault
    }

    var bestShinyURL: URL? {
        other?.officialArtwork.frontShiny ?? frontShiny
    }

    enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
        case frontShiny = "front_shiny"
        case other
    }
}

struct PokeAPIOtherSprites: Decodable {
    let officialArtwork: PokeAPIOfficialArtwork

    enum CodingKeys: String, CodingKey {
        case officialArtwork = "official-artwork"
    }
}

struct PokeAPIOfficialArtwork: Decodable {
    let frontDefault: URL?
    let frontShiny: URL?

    enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
        case frontShiny = "front_shiny"
    }
}

struct PokeAPITypeSlot: Decodable {
    let slot: Int
    let type: PokeAPIResource
}

struct PokeAPIAbilitySlot: Decodable {
    let slot: Int
    let isHidden: Bool
    let ability: PokeAPIResource

    enum CodingKeys: String, CodingKey {
        case slot
        case isHidden = "is_hidden"
        case ability
    }
}

struct PokeAPIGameIndex: Decodable {
    let version: PokeAPIResource
}

struct PokeAPISpeciesResponse: Decodable {
    let flavorTextEntries: [PokeAPIFlavorTextEntry]
    let genera: [PokeAPIGenus]
    let habitat: PokeAPIResource?
    let evolutionChain: PokeAPIURLReference
    let pokedexNumbers: [PokeAPIPokedexNumber]
    let varieties: [PokeAPIVariety]

    var englishFlavorText: String? {
        flavorTextEntries
            .first { $0.language.name == "en" }?
            .flavorText
            .cleanedPokeAPIText
    }

    var englishGenus: String? {
        genera.first { $0.language.name == "en" }?.genus
    }

    // Names of the regional Pokedexes this species belongs to (excluding the national dex).
    var regionalPokedexNames: [String] {
        pokedexNumbers.map(\.pokedex.name).filter { $0 != "national" }
    }

    enum CodingKeys: String, CodingKey {
        case flavorTextEntries = "flavor_text_entries"
        case genera
        case habitat
        case evolutionChain = "evolution_chain"
        case pokedexNumbers = "pokedex_numbers"
        case varieties
    }
}

struct PokeAPIPokedexNumber: Decodable {
    let pokedex: PokeAPIResource
}

struct PokeAPIVariety: Decodable {
    let isDefault: Bool
    let pokemon: PokeAPIResource

    enum CodingKeys: String, CodingKey {
        case isDefault = "is_default"
        case pokemon
    }
}

struct PokeAPIFlavorTextEntry: Decodable {
    let flavorText: String
    let language: PokeAPIResource

    enum CodingKeys: String, CodingKey {
        case flavorText = "flavor_text"
        case language
    }
}

struct PokeAPIGenus: Decodable {
    let genus: String
    let language: PokeAPIResource
}

struct PokeAPIAbilityResponse: Decodable {
    let effectEntries: [PokeAPIEffectEntry]
    let flavorTextEntries: [PokeAPIFlavorTextEntry]

    var englishDescription: String? {
        if let entry = effectEntries.first(where: { $0.language.name == "en" }) {
            return (entry.shortEffect ?? entry.effect)?.cleanedPokeAPIText
        }
        return flavorTextEntries.first(where: { $0.language.name == "en" })?.flavorText.cleanedPokeAPIText
    }

    enum CodingKeys: String, CodingKey {
        case effectEntries = "effect_entries"
        case flavorTextEntries = "flavor_text_entries"
    }
}

struct PokeAPIEffectEntry: Decodable {
    let effect: String?
    let shortEffect: String?
    let language: PokeAPIResource

    enum CodingKeys: String, CodingKey {
        case effect
        case shortEffect = "short_effect"
        case language
    }
}

struct PokeAPIEvolutionChainResponse: Decodable {
    let chain: PokeAPIEvolutionLink
}

struct PokeAPIEvolutionLink: Decodable {
    let species: PokeAPIResource
    let evolutionDetails: [PokeAPIEvolutionDetail]
    let evolvesTo: [PokeAPIEvolutionLink]

    enum CodingKeys: String, CodingKey {
        case species
        case evolutionDetails = "evolution_details"
        case evolvesTo = "evolves_to"
    }
}

struct PokeAPIEvolutionDetail: Decodable {
    let minLevel: Int?
    let minHappiness: Int?
    let item: PokeAPIResource?
    let trigger: PokeAPIResource?
    let timeOfDay: String

    var summary: String? {
        if let minLevel {
            return "Level \(minLevel)"
        }

        if let item {
            return item.name.displayName
        }

        if let minHappiness {
            return "Friendship \(minHappiness)"
        }

        if !timeOfDay.isEmpty {
            return timeOfDay.displayName
        }

        return trigger?.name.displayName
    }

    enum CodingKeys: String, CodingKey {
        case minLevel = "min_level"
        case minHappiness = "min_happiness"
        case item
        case trigger
        case timeOfDay = "time_of_day"
    }
}

enum PokeAPIError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "PokeAPI returned an invalid response."
        }
    }
}
