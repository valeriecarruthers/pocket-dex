//
//  ContentView.swift
//  Pocket Dex
//
//  Created by Valerie Carruthers on 2026-07-01.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var pokemon: [PokemonSummary] = []
    @State private var selectedPokemonID: PokemonSummary.ID?
    @State private var searchText = ""
    @State private var sortOption: PokemonSortOption = .pokedexNumber
    @State private var selectedRegion: PokemonRegion = .all
    @State private var isLoading = false
    @State private var loadingError: String?

    var body: some View {
        NavigationSplitView {
            PokemonListView(
                pokemon: filteredPokemon,
                selectedPokemonID: $selectedPokemonID,
                searchText: $searchText,
                sortOption: $sortOption,
                selectedRegion: $selectedRegion,
                isLoading: isLoading,
                loadingError: loadingError,
                retry: loadPokemon
            )
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 280, ideal: 340)
#endif
        } detail: {
            if let selectedPokemon {
                PokemonDetailView(
                    pokemon: selectedPokemon,
                    previousPokemon: adjacentPokemon.previous,
                    nextPokemon: adjacentPokemon.next,
                    selectPokemon: { selectedPokemonID = $0.id }
                )
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

    private var filteredPokemon: [PokemonSummary] {
        let regionFiltered = pokemon.filter { selectedRegion.contains($0.pokedexNumber) }
        let searched = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let searchFiltered: [PokemonSummary]
        if searched.isEmpty {
            searchFiltered = regionFiltered
        } else {
            searchFiltered = regionFiltered.filter { pokemon in
                pokemon.displayName.localizedStandardContains(searched)
                || String(pokemon.pokedexNumber).contains(searched)
            }
        }

        switch sortOption {
        case .pokedexNumber:
            return searchFiltered.sorted { $0.pokedexNumber < $1.pokedexNumber }
        case .name:
            return searchFiltered.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }
    }

    private func loadPokemonIfNeeded() async {
        guard pokemon.isEmpty else { return }
        await loadPokemon()
    }

    private func loadPokemon() async {
        isLoading = true
        loadingError = nil

        do {
            pokemon = try await PokeAPIClient().fetchAllPokemon()
            if selectedPokemonID == nil {
                selectedPokemonID = filteredPokemon.first?.id
            }
        } catch {
            loadingError = error.localizedDescription
        }

        isLoading = false
    }
}

private struct PokemonListView: View {
    let pokemon: [PokemonSummary]
    @Binding var selectedPokemonID: PokemonSummary.ID?
    @Binding var searchText: String
    @Binding var sortOption: PokemonSortOption
    @Binding var selectedRegion: PokemonRegion
    let isLoading: Bool
    let loadingError: String?
    let retry: () async -> Void

    var body: some View {
        List(selection: $selectedPokemonID) {
            if isLoading && pokemon.isEmpty {
                ProgressView("Loading Pokemon...")
            } else if let loadingError, pokemon.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Pokemon", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(loadingError)
                } actions: {
                    Button("Try Again") {
                        Task { await retry() }
                    }
                }
            } else if pokemon.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                Section("\(pokemon.count) Pokemon") {
                    ForEach(pokemon) { pokemon in
                        NavigationLink(value: pokemon.id) {
                            PokemonRow(pokemon: pokemon)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pocket Dex")
        .searchable(text: $searchText, prompt: "Name or number")
        .toolbar {
            ToolbarItemGroup {
                Picker("Region", selection: $selectedRegion) {
                    ForEach(PokemonRegion.allCases) { region in
                        Text(region.name).tag(region)
                    }
                }
                .pickerStyle(.menu)

                Picker("Sort", selection: $sortOption) {
                    ForEach(PokemonSortOption.allCases) { option in
                        Label(option.title, systemImage: option.systemImage).tag(option)
                    }
                }
                .pickerStyle(.menu)

                if isLoading {
                    ProgressView()
                }
            }
        }
        .refreshable {
            await retry()
        }
    }
}

private struct PokemonRow: View {
    let pokemon: PokemonSummary

    var body: some View {
        HStack(spacing: 12) {
            Text(pokemon.formattedPokedexNumber)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(pokemon.displayName)
                    .font(.headline)
                Text(pokemon.region.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PokemonDetailView: View {
    let pokemon: PokemonSummary
    let previousPokemon: PokemonSummary?
    let nextPokemon: PokemonSummary?
    let selectPokemon: (PokemonSummary) -> Void

    @State private var detail: PokemonDetail?
    @State private var isLoading = false
    @State private var loadingError: String?
    @State private var showingShiny = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isLoading && detail == nil {
                    ProgressView("Loading details...")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let loadingError, detail == nil {
                    ContentUnavailableView {
                        Label("Unable to Load Details", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(loadingError)
                    } actions: {
                        Button("Try Again") {
                            Task { await loadDetail() }
                        }
                    }
                } else if let detail {
                    PokemonHeroView(detail: detail, showingShiny: $showingShiny)
                    PokemonProfileView(detail: detail)
                    PokemonGamesView(games: detail.games)
                    EvolutionTreeView(nodes: detail.evolutionTree)
                    PokemonAdjacentControls(
                        previousPokemon: previousPokemon,
                        nextPokemon: nextPokemon,
                        selectPokemon: selectPokemon
                    )
                }
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle(pokemon.displayName)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    if let previousPokemon {
                        selectPokemon(previousPokemon)
                    }
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(previousPokemon == nil)

                Button {
                    if let nextPokemon {
                        selectPokemon(nextPokemon)
                    }
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .disabled(nextPokemon == nil)
            }
        }
        .task(id: pokemon.id) {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        loadingError = nil
        showingShiny = false

        do {
            detail = try await PokeAPIClient().fetchPokemonDetail(for: pokemon)
        } catch {
            loadingError = error.localizedDescription
            detail = nil
        }

        isLoading = false
    }
}

private struct PokemonHeroView: View {
    let detail: PokemonDetail
    @Binding var showingShiny: Bool

    private var activeImageURL: URL? {
        showingShiny ? detail.shinyImageURL : detail.regularImageURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                PokemonArtworkView(url: activeImageURL, title: detail.summary.displayName)
                    .frame(width: 180, height: 180)

                VStack(alignment: .leading, spacing: 12) {
                    Text(detail.summary.formattedPokedexNumber)
                        .font(.caption.monospacedDigit())
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(detail.summary.displayName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    if let genus = detail.genus {
                        Text(genus)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    TypeChips(types: detail.types)

                    Button {
                        showingShiny.toggle()
                    } label: {
                        Label(showingShiny ? "Show Regular" : "Show Shiny", systemImage: showingShiny ? "circle.lefthalf.filled" : "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .disabled(detail.shinyImageURL == nil)
                }
            }

            if let flavorText = detail.flavorText {
                Text(flavorText)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PokemonArtworkView: View {
    let url: URL?
    let title: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.55))

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                            .accessibilityLabel(title)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TypeChips: View {
    let types: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(types, id: \.self) { type in
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.tint.opacity(0.16), in: Capsule())
            }
        }
    }
}

private struct PokemonProfileView: View {
    let detail: PokemonDetail

    var body: some View {
        DetailSection(title: "Profile") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                StatCard(title: "Height", value: detail.heightText, systemImage: "ruler")
                StatCard(title: "Weight", value: detail.weightText, systemImage: "scalemass")
                StatCard(title: "Base XP", value: detail.baseExperienceText, systemImage: "star")
                StatCard(title: "Habitat", value: detail.habitat ?? "Unknown", systemImage: "leaf")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Abilities")
                    .font(.headline)
                FlowLayout(spacing: 8) {
                    ForEach(detail.abilities, id: \.self) { ability in
                        Text(ability.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.quaternary.opacity(0.7), in: Capsule())
                    }
                }
            }
        }
    }
}

private struct PokemonGamesView: View {
    let games: [String]

    var body: some View {
        DetailSection(title: "Games") {
            if games.isEmpty {
                Text("No game appearance data returned by PokeAPI.")
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(games, id: \.self) { game in
                        Text(game.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.quaternary.opacity(0.7), in: Capsule())
                    }
                }
            }
        }
    }
}

private struct EvolutionTreeView: View {
    let nodes: [EvolutionNode]

    var body: some View {
        DetailSection(title: "Evolution") {
            if nodes.isEmpty {
                Text("No evolution data returned by PokeAPI.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(nodes) { node in
                        EvolutionNodeView(node: node, level: 0)
                    }
                }
            }
        }
    }
}

private struct EvolutionNodeView: View {
    let node: EvolutionNode
    let level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PokemonArtworkView(url: node.spriteURL, title: node.displayName)
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.displayName)
                        .font(.headline)
                    Text(node.formattedPokedexNumber)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let requirement = node.requirement {
                        Text(requirement)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.leading, CGFloat(level) * 20)

            ForEach(node.children) { child in
                EvolutionNodeView(node: child, level: level + 1)
            }
        }
    }
}

private struct PokemonAdjacentControls: View {
    let previousPokemon: PokemonSummary?
    let nextPokemon: PokemonSummary?
    let selectPokemon: (PokemonSummary) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if let previousPokemon {
                    selectPokemon(previousPokemon)
                }
            } label: {
                Label(previousPokemon?.displayName ?? "Previous", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(previousPokemon == nil)

            Button {
                if let nextPokemon {
                    selectPokemon(nextPokemon)
                }
            } label: {
                Label(nextPokemon?.displayName ?? "Next", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(nextPokemon == nil)
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            content
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: spacing) { content }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: spacing)], alignment: .leading, spacing: spacing) { content }
            }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: spacing)], alignment: .leading, spacing: spacing) { content }
        }
    }
}

private struct PokemonSummary: Identifiable, Hashable {
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
}

private struct PokemonDetail {
    let summary: PokemonSummary
    let regularImageURL: URL?
    let shinyImageURL: URL?
    let types: [String]
    let abilities: [String]
    let games: [String]
    let height: Int
    let weight: Int
    let baseExperience: Int?
    let flavorText: String?
    let genus: String?
    let habitat: String?
    let evolutionTree: [EvolutionNode]

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

private struct EvolutionNode: Identifiable, Hashable {
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

private enum PokemonSortOption: String, CaseIterable, Identifiable {
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

private enum PokemonRegion: String, CaseIterable, Identifiable {
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

private struct PokeAPIClient {
    private let baseURL = URL(string: "https://pokeapi.co/api/v2")!
    private let session: URLSession = .shared
    private let decoder = JSONDecoder()

    func fetchAllPokemon() async throws -> [PokemonSummary] {
        let listURL = baseURL.appending(path: "pokemon-species")
            .appending(queryItems: [URLQueryItem(name: "limit", value: "2000")])
        let resourceList: PokeAPIResourceList = try await fetch(listURL)

        return resourceList.results.compactMap { resource in
            guard let id = resource.id else { return nil }
            return PokemonSummary(id: id, name: resource.name, url: resource.url)
        }
    }

    func fetchPokemonDetail(for summary: PokemonSummary) async throws -> PokemonDetail {
        async let pokemonResponse: PokeAPIPokemonResponse = fetch(baseURL.appending(path: "pokemon").appending(path: String(summary.id)))
        async let speciesResponse: PokeAPISpeciesResponse = fetch(summary.url)

        let (pokemon, species) = try await (pokemonResponse, speciesResponse)
        let evolutionChain: PokeAPIEvolutionChainResponse = try await fetch(species.evolutionChain.url)

        return PokemonDetail(
            summary: summary,
            regularImageURL: pokemon.sprites.bestRegularURL,
            shinyImageURL: pokemon.sprites.bestShinyURL,
            types: pokemon.types.sorted { $0.slot < $1.slot }.map(\.type.name),
            abilities: pokemon.abilities.sorted { $0.slot < $1.slot }.map { ability in
                ability.isHidden ? "\(ability.ability.name) hidden" : ability.ability.name
            },
            games: pokemon.gameIndices.map(\.version.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending },
            height: pokemon.height,
            weight: pokemon.weight,
            baseExperience: pokemon.baseExperience,
            flavorText: species.englishFlavorText,
            genus: species.englishGenus,
            habitat: species.habitat?.name.displayName,
            evolutionTree: [buildEvolutionNode(from: evolutionChain.chain)]
        )
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw PokeAPIError.invalidResponse
        }

        return try decoder.decode(T.self, from: data)
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

private struct PokeAPIResourceList: Decodable {
    let results: [PokeAPIResource]
}

private struct PokeAPIResource: Decodable, Hashable {
    let name: String
    let url: URL

    var id: Int? {
        url.pathComponents
            .last { component in Int(component) != nil }
            .flatMap(Int.init)
    }
}

private struct PokeAPIPokemonResponse: Decodable {
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

private struct PokeAPISprites: Decodable {
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

private struct PokeAPIOtherSprites: Decodable {
    let officialArtwork: PokeAPIOfficialArtwork

    enum CodingKeys: String, CodingKey {
        case officialArtwork = "official-artwork"
    }
}

private struct PokeAPIOfficialArtwork: Decodable {
    let frontDefault: URL?
    let frontShiny: URL?

    enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
        case frontShiny = "front_shiny"
    }
}

private struct PokeAPITypeSlot: Decodable {
    let slot: Int
    let type: PokeAPIResource
}

private struct PokeAPIAbilitySlot: Decodable {
    let slot: Int
    let isHidden: Bool
    let ability: PokeAPIResource

    enum CodingKeys: String, CodingKey {
        case slot
        case isHidden = "is_hidden"
        case ability
    }
}

private struct PokeAPIGameIndex: Decodable {
    let version: PokeAPIResource
}

private struct PokeAPISpeciesResponse: Decodable {
    let flavorTextEntries: [PokeAPIFlavorTextEntry]
    let genera: [PokeAPIGenus]
    let habitat: PokeAPIResource?
    let evolutionChain: PokeAPIResource

    var englishFlavorText: String? {
        flavorTextEntries
            .first { $0.language.name == "en" }?
            .flavorText
            .cleanedPokeAPIText
    }

    var englishGenus: String? {
        genera.first { $0.language.name == "en" }?.genus
    }

    enum CodingKeys: String, CodingKey {
        case flavorTextEntries = "flavor_text_entries"
        case genera
        case habitat
        case evolutionChain = "evolution_chain"
    }
}

private struct PokeAPIFlavorTextEntry: Decodable {
    let flavorText: String
    let language: PokeAPIResource

    enum CodingKeys: String, CodingKey {
        case flavorText = "flavor_text"
        case language
    }
}

private struct PokeAPIGenus: Decodable {
    let genus: String
    let language: PokeAPIResource
}

private struct PokeAPIEvolutionChainResponse: Decodable {
    let chain: PokeAPIEvolutionLink
}

private struct PokeAPIEvolutionLink: Decodable {
    let species: PokeAPIResource
    let evolutionDetails: [PokeAPIEvolutionDetail]
    let evolvesTo: [PokeAPIEvolutionLink]

    enum CodingKeys: String, CodingKey {
        case species
        case evolutionDetails = "evolution_details"
        case evolvesTo = "evolves_to"
    }
}

private struct PokeAPIEvolutionDetail: Decodable {
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

private enum PokeAPIError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "PokeAPI returned an invalid response."
        }
    }
}

private extension String {
    var displayName: String {
        split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    var cleanedPokeAPIText: String {
        replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\u{000C}", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
