//
//  ContentView.swift
//  Pocket Dex
//
//  Created by Valerie Carruthers on 2026-07-01.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ContentView: View {
    @State private var pokemon: [PokemonSummary] = []
    @State private var selectedPokemonID: PokemonSummary.ID?
    @State private var searchText = ""
    @State private var sortOption: PokemonSortOption = .pokedexNumber
    @State private var selectedRegion: PokemonRegion = .all
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
        return gameFiltered.filter { selectedRegion.contains($0.pokedexNumber) }
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

private struct PokemonListView: View {
    let pokemon: [PokemonSummary]
    @Binding var selectedPokemonID: PokemonSummary.ID?
    @Binding var searchText: String
    @Binding var sortOption: PokemonSortOption
    @Binding var selectedRegion: PokemonRegion
    let games: [PokemonGame]
    @Binding var selectedGame: PokemonGame?
    @Binding var includeEvolutionLines: Bool
    @Binding var showingShiny: Bool
    let isLoading: Bool
    let loadingError: String?
    let retry: () async -> Void

    @State private var indexBarVisible = false
    @State private var hideIndexBarWork: DispatchWorkItem?
    @State private var scrolledDown = false

    private var filtersActive: Bool {
        selectedRegion != .all || selectedGame != nil
    }

    var body: some View {
        galleryContent
        .navigationTitle("Pocket Dex")
        .searchable(text: $searchText, prompt: "Name or number")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu {
                    Picker("Region", selection: $selectedRegion) {
                        ForEach(PokemonRegion.allCases) { region in
                            regionLabel(region).tag(region)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Game", selection: $selectedGame) {
                        Text("All Games").tag(PokemonGame?.none)
                        ForEach(games) { game in
                            Text(game.displayName).tag(PokemonGame?.some(game))
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Sort", selection: $sortOption) {
                        ForEach(PokemonSortOption.allCases) { option in
                            Label(option.title, systemImage: option.systemImage).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                } label: {
                    Label("Filter & Sort", systemImage: filtersActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if isLoading {
                    ProgressView()
                }

                ShinyToggleButton(showingShiny: $showingShiny)
            }
        }
        .refreshable {
            await retry()
        }
    }

    private let gridColumns = [GridItem(.adaptive(minimum: 120), spacing: 16)]

    @ViewBuilder private var galleryContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id("galleryTop")

                if selectedRegion != .all || selectedGame != nil {
                    activeFilterChips
                        .padding(.top, 8)
                }

                if !searchText.isEmpty {
                    HStack(spacing: 8) {
                        evolutionLineToggle
                        searchShinyToggle
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                if pokemon.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, minHeight: 320)
                } else if sortOption == .pokedexNumber {
                    // Sorted by number, regions are contiguous, so show sticky region headers.
                    LazyVGrid(columns: gridColumns, spacing: 16, pinnedViews: [.sectionHeaders]) {
                        ForEach(regionSections) { section in
                            Section {
                                ForEach(section.pokemon) { pokemon in
                                    galleryCell(pokemon)
                                }
                            } header: {
                                regionHeader(section.region)
                            }
                        }
                    }
                    .padding()
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(pokemon) { pokemon in
                            galleryCell(pokemon)
                        }
                    }
                    .padding()
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldValue, newValue in
                if oldValue != newValue { revealIndexBar() }
                let isDown = newValue > 500
                if isDown != scrolledDown {
                    withAnimation(.easeInOut(duration: 0.2)) { scrolledDown = isDown }
                }
            }
            .overlay(alignment: .trailing) {
                if indexEntries.count > 1 && indexBarVisible {
                    SectionIndexBar(entries: indexEntries) { targetID in
                        proxy.scrollTo(targetID, anchor: .top)
                        revealIndexBar()
                    }
                    .padding(.trailing, 2)
                    .padding(.bottom, 64)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if scrolledDown {
                    Button {
                        withAnimation { proxy.scrollTo("galleryTop", anchor: .top) }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.headline)
                            .padding(14)
                            .background(.thinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(.tint.opacity(0.3), lineWidth: 1))
                    }
                    .accessibilityLabel("Scroll to top")
                    .padding(.trailing, 12)
                    .padding(.bottom, 16)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // Reveals the fast-scroll index and schedules it to fade out after a short idle period.
    private func revealIndexBar() {
        if !indexBarVisible {
            withAnimation(.easeIn(duration: 0.2)) { indexBarVisible = true }
        }
        hideIndexBarWork?.cancel()
        let work = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.4)) { indexBarVisible = false }
        }
        hideIndexBarWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    // Fast-scroll index entries, whose contents depend on the current sort/filters.
    private var indexEntries: [GalleryIndexEntry] {
        guard !pokemon.isEmpty else { return [] }

        switch sortOption {
        case .name:
            // Alphabet: the first Pokemon for each starting letter.
            var seen = Set<Character>()
            var result: [GalleryIndexEntry] = []
            for summary in pokemon {
                guard let first = summary.displayName.uppercased().first, first.isLetter else { continue }
                if seen.insert(first).inserted {
                    result.append(GalleryIndexEntry(id: result.count, label: String(first), targetPokemonID: summary.id))
                }
            }
            return result

        case .pokedexNumber where selectedRegion == .all && selectedGame == nil:
            // Regions: jump to the start of each region section.
            return regionSections.enumerated().compactMap { index, section in
                guard let first = section.pokemon.first else { return nil }
                return GalleryIndexEntry(id: index, label: section.region.shortName, targetPokemonID: first.id)
            }

        case .pokedexNumber:
            // A specific region/game is active: evenly spaced Pokedex-number markers.
            let count = pokemon.count
            let bucketCount = min(12, count)
            guard bucketCount > 0 else { return [] }
            return (0..<bucketCount).map { i in
                let summary = pokemon[i * count / bucketCount]
                return GalleryIndexEntry(id: i, label: "\(summary.pokedexNumber)", targetPokemonID: summary.id)
            }
        }
    }

    @ViewBuilder private func galleryCell(_ pokemon: PokemonSummary) -> some View {
        Button {
            selectedPokemonID = pokemon.id
        } label: {
            PokemonGalleryCell(
                pokemon: pokemon,
                showingShiny: showingShiny,
                isSelected: pokemon.id == selectedPokemonID
            )
        }
        .buttonStyle(.plain)
    }

    // Region name with its dex number range appended in a smaller, secondary style.
    private func regionLabel(_ region: PokemonRegion) -> Text {
        var label = AttributedString(region.name)
        if let range = region.numberRangeText {
            var suffix = AttributedString("  \(range)")
            suffix.font = .caption2
            suffix.foregroundColor = .secondary
            label.append(suffix)
        }
        return Text(label)
    }

    private func regionHeader(_ region: PokemonRegion) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(.tint)
                .frame(width: 4, height: 24)

            Text(region.name)
                .font(.system(.title3, design: .rounded).weight(.bold))

            if let range = region.numberRangeText {
                Text(range)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    // Groups the (number-sorted) Pokemon into contiguous region sections.
    private var regionSections: [RegionSection] {
        var sections: [RegionSection] = []
        for summary in pokemon {
            if let last = sections.indices.last, sections[last].region == summary.region {
                sections[last].pokemon.append(summary)
            } else {
                sections.append(RegionSection(region: summary.region, pokemon: [summary]))
            }
        }
        return sections
    }

    // Shows the currently active region/game filters as removable chips.
    @ViewBuilder private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if selectedRegion != .all {
                    FilterChip(title: selectedRegion.name, systemImage: "map") {
                        selectedRegion = .all
                    }
                }
                if let game = selectedGame {
                    FilterChip(title: game.displayName, systemImage: "gamecontroller") {
                        selectedGame = nil
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // Shiny toggle for the results area — the nav-bar shiny button is hidden while searching.
    private var searchShinyToggle: some View {
        Button {
            showingShiny.toggle()
        } label: {
            Image(systemName: showingShiny ? "sparkles.rectangle.stack.fill" : "sparkles")
                .font(.subheadline)
                .padding(12)
                .background(
                    (showingShiny ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.12)),
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(showingShiny ? .yellow : .secondary)
        .accessibilityLabel("Shiny")
    }

    // A button shown while searching that expands results to each match's full evolution family.
    private var evolutionLineToggle: some View {
        Button {
            includeEvolutionLines.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                Text(includeEvolutionLines ? "Showing full evolution lines" : "Include evolution lines")
                    .fontWeight(.medium)
                Spacer(minLength: 0)
                Image(systemName: includeEvolutionLines ? "checkmark.circle.fill" : "circle")
            }
            .font(.subheadline)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                (includeEvolutionLines ? Color.green.opacity(0.18) : Color.gray.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
        .tint(includeEvolutionLines ? .green : .secondary)
    }

    @ViewBuilder private var emptyState: some View {
        if isLoading {
            ProgressView("Loading Pokemon...")
        } else if let loadingError {
            ContentUnavailableView {
                Label("Unable to Load Pokemon", systemImage: "wifi.exclamationmark")
            } description: {
                Text(loadingError)
            } actions: {
                Button("Try Again") {
                    Task { await retry() }
                }
            }
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let systemImage: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Image(systemName: "xmark.circle.fill")
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.tint.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel("Remove \(title) filter")
    }
}

private struct RegionSection: Identifiable {
    let region: PokemonRegion
    var pokemon: [PokemonSummary]
    var id: PokemonRegion { region }
}

private struct GalleryIndexEntry: Identifiable {
    let id: Int
    let label: String
    let targetPokemonID: Int
}


// A Contacts-style vertical index for jumping through the gallery; drag or tap to scroll.
private struct SectionIndexBar: View {
    let entries: [GalleryIndexEntry]
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 1) {
                ForEach(entries) { entry in
                    Text(entry.label)
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.tint)
                        .fixedSize()
                        .rotationEffect(.degrees(90))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !entries.isEmpty, geo.size.height > 0 else { return }
                        let fraction = value.location.y / geo.size.height
                        let index = min(entries.count - 1, max(0, Int(fraction * CGFloat(entries.count))))
                        onSelect(entries[index].targetPokemonID)
                    }
            )
        }
        .frame(width: 18)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .padding(.vertical, 8)
    }
}

private struct ShinyToggleButton: View {
    @Binding var showingShiny: Bool

    var body: some View {
        Button {
            showingShiny.toggle()
        } label: {
            Label("Shiny", systemImage: showingShiny ? "sparkles.rectangle.stack.fill" : "sparkles")
        }
        .tint(showingShiny ? .yellow : nil)
        .help(showingShiny ? "Show regular artwork" : "Show shiny artwork")
    }
}

private struct PokemonGalleryCell: View {
    let pokemon: PokemonSummary
    let showingShiny: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            PokemonArtworkView(
                url: showingShiny ? pokemon.shinyArtworkURL : pokemon.artworkURL,
                lowResURL: showingShiny ? pokemon.shinySpriteURL : pokemon.spriteURL,
                title: pokemon.displayName
            )
            .frame(height: 120)

            Text(pokemon.displayName)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(pokemon.formattedPokedexNumber)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(isSelected ? 0.9 : 0.35), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.tint, lineWidth: isSelected ? 3 : 0)
        }
    }
}

private struct PokemonDetailView: View {
    let pokemon: PokemonSummary
    let previousPokemon: PokemonSummary?
    let nextPokemon: PokemonSummary?
    @Binding var showingShiny: Bool
    let selectPokemon: (PokemonSummary) -> Void
    let selectPokemonID: (Int) -> Void

    @State private var detail: PokemonDetail?
    @State private var isLoading = false
    @State private var loadingError: String?
    @State private var gameAppearances: [PokemonGame]?

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
                    PokemonGamesView(games: gameAppearances)
                    EvolutionTreeView(nodes: detail.evolutionTree, selectPokemonID: selectPokemonID)
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
            ToolbarItemGroup(placement: .primaryAction) {
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

                ShinyToggleButton(showingShiny: $showingShiny)
            }
        }
        .task(id: pokemon.id) {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        loadingError = nil
        gameAppearances = nil

        do {
            detail = try await PokeAPIClient.shared.fetchPokemonDetail(for: pokemon)
        } catch {
            loadingError = error.localizedDescription
            detail = nil
        }

        isLoading = false

        // Resolve which games this Pokemon appears in (heavier; fills the games section when ready).
        if let detail {
            gameAppearances = (try? await PokeAPIClient.shared.fetchGamesForSpecies(pokedexNames: detail.pokedexNames)) ?? []
        }
    }
}

private struct PokemonHeroView: View {
    let detail: PokemonDetail
    @Binding var showingShiny: Bool

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var activeImageURL: URL? {
        showingShiny ? detail.shinyImageURL : detail.regularImageURL
    }

    // The iPhone (compact width) keeps the smaller artwork; iPad and Mac get a more prominent image.
    private var isCompact: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var artworkSize: CGFloat {
        isCompact ? 180 : 300
    }

    private var primaryTypeColor: Color? {
        detail.types.first.map(Color.pokemonType)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                PokemonArtworkView(
                    url: activeImageURL,
                    lowResURL: showingShiny ? detail.summary.shinySpriteURL : detail.summary.spriteURL,
                    title: detail.summary.displayName,
                    tint: primaryTypeColor
                )
                    .frame(width: artworkSize, height: artworkSize)

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
    var lowResURL: URL? = nil
    let title: String
    var tint: Color? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.55))

            RoundedRectangle(cornerRadius: 8)
                .fill(tint?.opacity(0.18) ?? Color.clear)

            CachedAsyncImage(url: url, lowResURL: lowResURL, title: title)
                .padding(12)
        }
    }
}

#if canImport(UIKit)
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage
#endif

private extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: platformImage)
        #endif
    }
}

/// Loads Pokemon images with an in-memory + on-disk cache so scrolling back is instant
/// and already-seen images never re-download.
private final class PokemonImageCache {
    static let shared = PokemonImageCache()

    private let memory = NSCache<NSURL, PlatformImage>()
    private let session: URLSession

    private init() {
        memory.countLimit = 600
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 40 * 1024 * 1024,
            diskCapacity: 400 * 1024 * 1024,
            diskPath: "PokeAPIImages"
        )
        session = URLSession(configuration: configuration)
    }

    func cachedImage(for url: URL) -> PlatformImage? {
        memory.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> PlatformImage? {
        if let cached = cachedImage(for: url) { return cached }
        guard let (data, _) = try? await session.data(from: url),
              let image = PlatformImage(data: data) else { return nil }
        memory.setObject(image, forKey: url as NSURL)
        return image
    }
}

/// Progressive, cached image view: shows the tiny sprite first (near-instant) then swaps in the
/// high-resolution artwork once it arrives. A cached high-res image appears immediately.
private struct CachedAsyncImage: View {
    let url: URL?
    var lowResURL: URL? = nil
    let title: String

    @State private var image: PlatformImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(title)
            } else if didFail {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        image = nil
        didFail = false

        guard let url else {
            didFail = true
            return
        }

        // Instant path: high-res already decoded in memory.
        if let cached = PokemonImageCache.shared.cachedImage(for: url) {
            image = cached
            return
        }

        // Progressive preview: show the tiny sprite while the artwork downloads.
        if let lowResURL,
           PokemonImageCache.shared.cachedImage(for: url) == nil,
           let preview = await PokemonImageCache.shared.image(for: lowResURL) {
            if image == nil { image = preview }
        }

        if let full = await PokemonImageCache.shared.image(for: url) {
            image = full
        } else if image == nil {
            didFail = true
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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.pokemonType(type), in: Capsule())
            }
        }
    }
}

private struct PokemonProfileView: View {
    let detail: PokemonDetail

    var body: some View {
        DetailSection(title: "Profile") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                StatCard(title: "Region", value: detail.summary.region.name, systemImage: "map")
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
                        AbilityChip(ability: ability)
                    }
                }
            }
        }
    }
}

private struct AbilityChip: View {
    let ability: PokemonAbility

    @State private var showingInfo = false
    @State private var description: String?
    @State private var isLoading = false

    private var color: Color { Color.forAbility(ability.name) }

    var body: some View {
        Button {
            showingInfo = true
            Task { await loadDescription() }
        } label: {
            HStack(spacing: 4) {
                Text(ability.displayName)
                    .fontWeight(.medium)
                if ability.isHidden {
                    Image(systemName: "eye.slash")
                        .imageScale(.small)
                }
                Image(systemName: "info.circle")
                    .imageScale(.small)
                    .opacity(0.6)
            }
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ability.isHidden ? "\(ability.displayName), hidden ability" : ability.displayName)
        .popover(isPresented: $showingInfo) {
            abilityPopover
        }
    }

    private var abilityPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(ability.displayName)
                    .font(.headline)
                    .foregroundStyle(color)
                if ability.isHidden {
                    Text("Hidden")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2), in: Capsule())
                }
            }

            if isLoading {
                ProgressView()
            } else if let description {
                Text(description)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No description available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 320, alignment: .leading)
        .presentationCompactAdaptation(.popover)
    }

    private func loadDescription() async {
        guard description == nil else { return }
        isLoading = true
        description = try? await PokeAPIClient.shared.fetchAbilityDescription(named: ability.name)
        isLoading = false
    }
}

private struct PokemonGamesView: View {
    // nil while the game appearances are still loading.
    let games: [PokemonGame]?

    // Games grouped by the generation whose region they cover (remakes group with the original).
    private var groupedGames: [(generation: PokemonGeneration?, games: [PokemonGame])] {
        let grouped = Dictionary(grouping: games ?? []) { PokemonGeneration.forVersionGroup($0.name) }
        var result: [(PokemonGeneration?, [PokemonGame])] = PokemonGeneration.allCases.compactMap { generation in
            guard let list = grouped[generation], !list.isEmpty else { return nil }
            return (generation, list.sorted { $0.id < $1.id })
        }
        if let others = grouped[nil], !others.isEmpty {
            result.append((nil, others.sorted { $0.id < $1.id }))
        }
        return result
    }

    var body: some View {
        DetailSection(title: "Games") {
            if games == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if groupedGames.isEmpty {
                Text("No game appearances found.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groupedGames, id: \.generation) { group in
                        generationSection(group.generation, games: group.games)
                    }
                }
            }
        }
    }

    private func generationSection(_ generation: PokemonGeneration?, games: [PokemonGame]) -> some View {
        let color = generation?.color ?? .gray
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(generation?.title ?? "Other")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                if let region = generation?.regionName {
                    Text(region)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            FlowLayout(spacing: 8) {
                ForEach(games) { game in
                    Text(game.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.22), in: Capsule())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }
}

private enum PokemonGeneration: Int, CaseIterable, Identifiable {
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

private struct EvolutionTreeView: View {
    let nodes: [EvolutionNode]
    let selectPokemonID: (Int) -> Void

    var body: some View {
        DetailSection(title: "Evolution") {
            if nodes.isEmpty {
                Text("No evolution data returned by PokeAPI.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(nodes) { node in
                        EvolutionNodeView(node: node, level: 0, selectPokemonID: selectPokemonID)
                    }
                }
            }
        }
    }
}

private struct EvolutionNodeView: View {
    let node: EvolutionNode
    let level: Int
    let selectPokemonID: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                selectPokemonID(node.id)
            } label: {
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

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(node.id <= 0)
            .padding(.leading, CGFloat(level) * 20)

            ForEach(node.children) { child in
                EvolutionNodeView(node: child, level: level + 1, selectPokemonID: selectPokemonID)
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
}

/// A playable game, modelled on PokeAPI's version groups (e.g. "scarlet-violet").
private struct PokemonGame: Identifiable, Hashable {
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

private struct PokemonAbility: Hashable {
    let name: String
    let isHidden: Bool

    var displayName: String { name.displayName }
}

private struct PokemonDetail {
    let summary: PokemonSummary
    let regularImageURL: URL?
    let shinyImageURL: URL?
    let types: [String]
    let abilities: [PokemonAbility]
    let pokedexNames: [String]
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

private struct PokeAPIClient {
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

        return PokemonDetail(
            summary: summary,
            regularImageURL: pokemon.sprites.bestRegularURL,
            shinyImageURL: pokemon.sprites.bestShinyURL,
            types: pokemon.types.sorted { $0.slot < $1.slot }.map(\.type.name),
            abilities: pokemon.abilities.sorted { $0.slot < $1.slot }.map { ability in
                PokemonAbility(name: ability.ability.name, isHidden: ability.isHidden)
            },
            pokedexNames: species.regionalPokedexNames,
            height: pokemon.height,
            weight: pokemon.weight,
            baseExperience: pokemon.baseExperience,
            flavorText: species.englishFlavorText,
            genus: species.englishGenus,
            habitat: species.habitat?.name.displayName,
            evolutionTree: evolutionTree
        )
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

private actor PokeAPIDiskCache {
    static let shared = PokeAPIDiskCache()

    private let directory: URL
    private let fileManager = FileManager.default

    private init() {
        let baseDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = baseDirectory.appending(path: "PokeAPIResponses", directoryHint: .isDirectory)
    }

    func data(for url: URL) throws -> Data? {
        try prepareDirectory()

        let fileURL = fileURL(for: url)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try Data(contentsOf: fileURL)
    }

    func save(_ data: Data, for url: URL) throws {
        try prepareDirectory()
        try data.write(to: fileURL(for: url), options: .atomic)
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for url: URL) -> URL {
        let key = Data(url.absoluteString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directory.appending(path: key).appendingPathExtension("json")
    }
}

private struct PokeAPIResourceList: Decodable {
    let results: [PokeAPIResource]
}

private struct PokeAPIURLReference: Decodable {
    let url: URL
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

private struct PokeAPIVersionGroupResponse: Decodable {
    let pokedexes: [PokeAPIResource]
}

private struct PokeAPIPokedexResponse: Decodable {
    let pokemonEntries: [PokeAPIPokedexEntry]

    enum CodingKeys: String, CodingKey {
        case pokemonEntries = "pokemon_entries"
    }
}

private struct PokeAPIPokedexEntry: Decodable {
    let pokemonSpecies: PokeAPIResource

    enum CodingKeys: String, CodingKey {
        case pokemonSpecies = "pokemon_species"
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
    let evolutionChain: PokeAPIURLReference
    let pokedexNumbers: [PokeAPIPokedexNumber]

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
    }
}

private struct PokeAPIPokedexNumber: Decodable {
    let pokedex: PokeAPIResource
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

private struct PokeAPIAbilityResponse: Decodable {
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

private struct PokeAPIEffectEntry: Decodable {
    let effect: String?
    let shortEffect: String?
    let language: PokeAPIResource

    enum CodingKeys: String, CodingKey {
        case effect
        case shortEffect = "short_effect"
        case language
    }
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

private extension Color {
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
