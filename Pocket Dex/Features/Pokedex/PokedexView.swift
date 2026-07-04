//
//  PokedexView.swift
//  Pocket Dex
//
//  The Pokedex feature root: a NavigationSplitView driving the gallery list and detail,
//  and the owner of all filter/search/loading state.
//

import SwiftUI
import SwiftData

struct PokedexView: View {
    @State private var pokemon: [PokemonSummary] = []
    @State private var selectedPokemonID: PokemonSummary.ID?
    @State private var searchText = ""
    @State private var sortOption: PokemonSortOption = .pokedexNumber
    @State private var selectedRegion: PokemonRegion = .all
    @State private var selectedFormFilter: PokemonFormFilter = .all
    @State private var games: [PokemonGame] = []
    @State private var selectedGame: PokemonGame?
    @State private var gameSpeciesIDs: Set<Int>?
    @State private var gameFilterCache: [Int: Set<Int>] = [:]
    @State private var isLoadingGameFilter = false
    @State private var includeEvolutionLines = false
    @State private var expandedEvolutionIDs: Set<Int> = []
    @State private var evolutionFamilyCache: [Int: [Int]] = [:]
    @State private var isLoadingEvolutions = false
    @State private var showingShiny = false
    @State private var isLoading = false
    @State private var loadingError: String?

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    // On iPad/Mac the detail column is always visible, so pre-selecting the first Pokemon fills it.
    // On iPhone (compact) that would push straight into a detail view, so we stay on the list instead.
    private var autoSelectsFirstPokemon: Bool {
        #if os(iOS)
        horizontalSizeClass != .compact
        #else
        true
        #endif
    }

    var body: some View {
        NavigationSplitView {
            PokemonListView(
                pokemon: filteredPokemon,
                selectedPokemonID: $selectedPokemonID,
                searchText: $searchText,
                sortOption: $sortOption,
                selectedRegion: $selectedRegion,
                selectedFormFilter: $selectedFormFilter,
                games: games,
                selectedGame: $selectedGame,
                includeEvolutionLines: $includeEvolutionLines,
                showingShiny: $showingShiny,
                isLoading: isLoading || isLoadingGameFilter || isLoadingEvolutions,
                loadingError: loadingError,
                retry: loadPokemon
            )
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 280, ideal: 340)
#endif
            // On iPhone the gallery has no detail column and its cells aren't NavigationLinks,
            // so push the detail explicitly for the selected Pokemon.
            .navigationDestination(item: compactGalleryDetail) { pokemon in
                detailView(for: pokemon)
            }
        } detail: {
            if let selectedPokemon {
                detailView(for: selectedPokemon)
            } else {
                ContentUnavailableView(
                    "Choose a Pokemon",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Select a Pokemon from the list to view its details.")
                )
            }
        }
        .task {
            await loadPokemonIfNeeded()
        }
        .task(id: selectedGame) {
            await applyGameFilter()
        }
        .task(id: evolutionExpansionKey) {
            await updateEvolutionExpansion()
        }
    }

    @ViewBuilder
    private func detailView(for pokemon: PokemonSummary) -> some View {
        PokemonDetailView(
            pokemon: pokemon,
            previousPokemon: adjacentPokemon.previous,
            nextPokemon: adjacentPokemon.next,
            showingShiny: $showingShiny,
            selectPokemon: { selectedPokemonID = $0.id },
            selectPokemonID: { selectedPokemonID = $0 }
        )
    }

    // Drives the pushed detail on compact width, where there is no detail column and the gallery
    // cells aren't NavigationLinks. On regular width the detail column handles it instead.
    private var compactGalleryDetail: Binding<PokemonSummary?> {
        Binding(
            get: {
                guard !autoSelectsFirstPokemon else { return nil }
                return selectedPokemon
            },
            set: { newValue in
                if newValue == nil { selectedPokemonID = nil }
            }
        )
    }

    private var selectedPokemon: PokemonSummary? {
        guard let selectedPokemonID else { return nil }
        return pokemon.first { $0.id == selectedPokemonID }
    }

    private var adjacentPokemon: (previous: PokemonSummary?, next: PokemonSummary?) {
        guard let selectedPokemonID,
              let index = filteredPokemon.firstIndex(where: { $0.id == selectedPokemonID }) else {
            return (nil, nil)
        }

        let previous = index > 0 ? filteredPokemon[index - 1] : nil
        let next = index < filteredPokemon.count - 1 ? filteredPokemon[index + 1] : nil
        return (previous, next)
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Pokemon passing the game and region filters, before any text search.
    private var gameAndRegionFiltered: [PokemonSummary] {
        let gameFiltered: [PokemonSummary]
        if let gameSpeciesIDs {
            gameFiltered = pokemon.filter { gameSpeciesIDs.contains($0.id) }
        } else {
            gameFiltered = pokemon
        }
        let regionFiltered = gameFiltered.filter { selectedRegion.contains($0.pokedexNumber) }

        guard selectedFormFilter != .all else { return regionFiltered }
        return regionFiltered.filter { selectedFormFilter.matches($0) }
    }

    private func matchesSearch(_ pokemon: PokemonSummary, _ searched: String) -> Bool {
        pokemon.displayName.localizedStandardContains(searched)
            || String(pokemon.pokedexNumber).contains(searched)
    }

    // Pokemon matching the search text directly — the seeds for evolution-line expansion.
    private var directSearchMatches: [PokemonSummary] {
        let searched = trimmedSearch
        guard !searched.isEmpty else { return gameAndRegionFiltered }
        return gameAndRegionFiltered.filter { matchesSearch($0, searched) }
    }

    private var filteredPokemon: [PokemonSummary] {
        let searched = trimmedSearch
        let filtered: [PokemonSummary]
        if searched.isEmpty {
            filtered = gameAndRegionFiltered
        } else {
            filtered = gameAndRegionFiltered.filter { pokemon in
                matchesSearch(pokemon, searched)
                    || (includeEvolutionLines && expandedEvolutionIDs.contains(pokemon.id))
            }
        }

        switch sortOption {
        case .pokedexNumber:
            return filtered.sorted { $0.pokedexNumber < $1.pokedexNumber }
        case .name:
            return filtered.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }
    }

    // Identifies which search matches to expand; changes here re-run the expansion task.
    private var evolutionExpansionKey: [Int] {
        guard includeEvolutionLines, !trimmedSearch.isEmpty else { return [] }
        return directSearchMatches.map(\.id)
    }

    private func loadPokemonIfNeeded() async {
        guard pokemon.isEmpty else { return }
        await loadPokemon()
    }

    private func loadPokemon() async {
        isLoading = true
        loadingError = nil

        do {
            pokemon = try await PokeAPIClient.shared.fetchAllPokemon()
            if selectedPokemonID == nil, autoSelectsFirstPokemon {
                selectedPokemonID = filteredPokemon.first?.id
            }
        } catch {
            loadingError = error.localizedDescription
        }

        if games.isEmpty {
            games = (try? await PokeAPIClient.shared.fetchGames()) ?? []
        }

        isLoading = false
    }

    // Resolves which species appear in the selected game (cached per game) and updates the filter.
    private func applyGameFilter() async {
        guard let selectedGame else {
            gameSpeciesIDs = nil
            return
        }

        if let cached = gameFilterCache[selectedGame.id] {
            gameSpeciesIDs = cached
            return
        }

        isLoadingGameFilter = true
        defer { isLoadingGameFilter = false }

        if let ids = try? await PokeAPIClient.shared.fetchSpeciesIDs(forGame: selectedGame) {
            gameFilterCache[selectedGame.id] = ids
            // Guard against a race if the user changed games while this was loading.
            if self.selectedGame == selectedGame {
                gameSpeciesIDs = ids
            }
        }
    }

    // Expands the current search matches to include every member of their evolution families.
    private func updateEvolutionExpansion() async {
        let seedIDs = evolutionExpansionKey
        guard !seedIDs.isEmpty else {
            expandedEvolutionIDs = []
            return
        }

        isLoadingEvolutions = true
        defer { isLoadingEvolutions = false }

        var union = Set<Int>()
        for id in seedIDs {
            if Task.isCancelled { return }

            if let family = evolutionFamilyCache[id] {
                union.formUnion(family)
            } else if let family = try? await PokeAPIClient.shared.fetchEvolutionFamily(forSpeciesID: id) {
                // Cache the whole family under each of its members.
                for member in family { evolutionFamilyCache[member] = family }
                union.formUnion(family)
            }
        }

        if !Task.isCancelled {
            expandedEvolutionIDs = union
        }
    }
}

#Preview {
    PokedexView()
        .modelContainer(for: Item.self, inMemory: true)
}
