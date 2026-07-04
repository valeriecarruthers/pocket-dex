//
//  PokeAPIClient.swift
//  Pocket Dex
//
//  Networking client for pokeapi.co, with layered URL + on-disk response caching and retries.
//

import Foundation

struct PokeAPIClient {
    static let shared = PokeAPIClient()

    private let baseURL = URL(string: "https://pokeapi.co/api/v2")!
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: "PokeAPIURLCache"
        )
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        return URLSession(configuration: configuration)
    }()
    private let decoder = JSONDecoder()
    private let diskCache = PokeAPIDiskCache.shared

    private init() { }

    func fetchAllPokemon() async throws -> [PokemonSummary] {
        let listURL = baseURL.appending(path: "pokemon-species")
            .appending(queryItems: [URLQueryItem(name: "limit", value: "2000")])
        let resourceList: PokeAPIResourceList = try await fetch(listURL)

        return resourceList.results.compactMap { resource in
            guard let id = resource.id else { return nil }
            return PokemonSummary(id: id, name: resource.name, url: resource.url)
        }
    }

    func fetchGames() async throws -> [PokemonGame] {
        let listURL = baseURL.appending(path: "version-group")
            .appending(queryItems: [URLQueryItem(name: "limit", value: "100")])
        let resourceList: PokeAPIResourceList = try await fetch(listURL)

        return resourceList.results
            .compactMap { resource in
                guard let id = resource.id else { return nil }
                return PokemonGame(id: id, name: resource.name, url: resource.url)
            }
            .sorted { $0.id < $1.id }
    }

    /// The national dex ids of every species appearing in the given game's Pokedex(es).
    func fetchSpeciesIDs(forGame game: PokemonGame) async throws -> Set<Int> {
        let versionGroup: PokeAPIVersionGroupResponse = try await fetch(game.url)

        var ids = Set<Int>()
        for pokedex in versionGroup.pokedexes {
            guard let dex: PokeAPIPokedexResponse = try? await fetch(pokedex.url) else { continue }
            for entry in dex.pokemonEntries {
                if let id = entry.pokemonSpecies.id {
                    ids.insert(id)
                }
            }
        }
        return ids
    }

    /// The games (version groups) a species appears in — determined by intersecting the species'
    /// regional Pokedexes with each game's Pokedexes. Covers modern and offshoot games that the
    /// legacy game_indices field omits.
    func fetchGamesForSpecies(pokedexNames: [String]) async throws -> [PokemonGame] {
        let speciesDexes = Set(pokedexNames)
        guard !speciesDexes.isEmpty else { return [] }

        let games = try await fetchGames()

        return await withTaskGroup(of: PokemonGame?.self) { group in
            for game in games {
                group.addTask {
                    guard let versionGroup: PokeAPIVersionGroupResponse = try? await self.fetch(game.url) else {
                        return nil
                    }
                    let gameDexes = Set(versionGroup.pokedexes.map(\.name))
                    return gameDexes.isDisjoint(with: speciesDexes) ? nil : game
                }
            }

            var result: [PokemonGame] = []
            for await found in group where found != nil {
                result.append(found!)
            }
            return result.sorted { $0.id < $1.id }
        }
    }

    /// A short description of what an ability does (fetched on demand, cached on disk).
    func fetchAbilityDescription(named name: String) async throws -> String? {
        let url = baseURL.appending(path: "ability").appending(path: name)
        let response: PokeAPIAbilityResponse = try await fetch(url)
        return response.englishDescription
    }

    /// The national dex ids of every species in the given species' evolution family.
    func fetchEvolutionFamily(forSpeciesID id: Int) async throws -> [Int] {
        let species: PokeAPISpeciesResponse = try await fetch(speciesURL(for: id))
        let chain: PokeAPIEvolutionChainResponse = try await fetch(species.evolutionChain.url)

        var ids: [Int] = []
        func walk(_ link: PokeAPIEvolutionLink) {
            if let sid = link.species.id { ids.append(sid) }
            link.evolvesTo.forEach(walk)
        }
        walk(chain.chain)
        return ids
    }

    func fetchPokemonDetail(for summary: PokemonSummary) async throws -> PokemonDetail {
        let pokemon: PokeAPIPokemonResponse = try await fetch(pokemonURL(for: summary.id))
        let species: PokeAPISpeciesResponse = try await fetch(speciesURL(for: summary.id))
        let evolutionTree: [EvolutionNode]

        do {
            let evolutionChain: PokeAPIEvolutionChainResponse = try await fetch(species.evolutionChain.url)
            evolutionTree = [buildEvolutionNode(from: evolutionChain.chain)]
        } catch {
            evolutionTree = []
        }

        let forms = species.varieties.map { variety in
            PokemonForm(
                name: variety.pokemon.name,
                url: variety.pokemon.url,
                isDefault: variety.isDefault,
                label: formLabel(variety.pokemon.name, speciesName: summary.name)
            )
        }

        return PokemonDetail(
            summary: summary,
            pokedexNames: species.regionalPokedexNames,
            flavorText: species.englishFlavorText,
            genus: species.englishGenus,
            habitat: species.habitat?.name.displayName,
            evolutionTree: evolutionTree,
            forms: forms,
            defaultForm: makeFormDetail(from: pokemon)
        )
    }

    // Loads the form-specific data for an alternate variety's Pokemon resource.
    func fetchFormDetail(url: URL) async throws -> PokemonFormDetail {
        let pokemon: PokeAPIPokemonResponse = try await fetch(url)
        return makeFormDetail(from: pokemon)
    }

    private func makeFormDetail(from pokemon: PokeAPIPokemonResponse) -> PokemonFormDetail {
        PokemonFormDetail(
            regularImageURL: pokemon.sprites.bestRegularURL,
            shinyImageURL: pokemon.sprites.bestShinyURL,
            types: pokemon.types.sorted { $0.slot < $1.slot }.map(\.type.name),
            abilities: pokemon.abilities.sorted { $0.slot < $1.slot }.map { ability in
                PokemonAbility(name: ability.ability.name, isHidden: ability.isHidden)
            },
            height: pokemon.height,
            weight: pokemon.weight,
            baseExperience: pokemon.baseExperience
        )
    }

    // Human-readable form name derived by stripping the species prefix (e.g. "zapdos-galar" -> "Galar").
    private func formLabel(_ formName: String, speciesName: String) -> String {
        if formName == speciesName { return "Default" }
        if formName.hasPrefix(speciesName + "-") {
            return String(formName.dropFirst(speciesName.count + 1)).displayName
        }
        return formName.displayName
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        if let cachedData = try? await diskCache.data(for: url) {
            return try decoder.decode(T.self, from: cachedData)
        }

        var lastError: Error?

        for attempt in 0..<3 {
            do {
                let data = try await fetchDataOnce(url)
                try? await diskCache.save(data, for: url)
                return try decoder.decode(T.self, from: data)
            } catch {
                if Task.isCancelled {
                    throw error
                }

                if let cachedData = try? await diskCache.data(for: url) {
                    return try decoder.decode(T.self, from: cachedData)
                }

                lastError = error

                guard attempt < 2, shouldRetry(error) else {
                    throw error
                }

                try await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
            }
        }

        throw lastError ?? PokeAPIError.invalidResponse
    }

    private func fetchDataOnce(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw PokeAPIError.invalidResponse
        }

        return data
    }

    private func shouldRetry(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }

        switch urlError.code {
        case .cancelled,
             .badURL,
             .unsupportedURL,
             .userAuthenticationRequired,
             .userCancelledAuthentication:
            return false
        default:
            return true
        }
    }

    private func pokemonURL(for id: Int) -> URL {
        baseURL.appending(path: "pokemon").appending(path: String(id))
    }

    private func speciesURL(for id: Int) -> URL {
        baseURL.appending(path: "pokemon-species").appending(path: String(id))
    }

    private func buildEvolutionNode(from chain: PokeAPIEvolutionLink) -> EvolutionNode {
        EvolutionNode(
            id: chain.species.id ?? 0,
            name: chain.species.name,
            requirement: chain.evolutionDetails.first?.summary,
            children: chain.evolvesTo.map(buildEvolutionNode)
        )
    }
}
