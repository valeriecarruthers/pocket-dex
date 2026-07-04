//
//  PokemonListView.swift
//  Pocket Dex
//
//  The gallery grid: region sections, filter chips, search toggles, and fast-scroll index.
//

import SwiftUI

struct PokemonListView: View {
    let pokemon: [PokemonSummary]
    @Binding var selectedPokemonID: PokemonSummary.ID?
    @Binding var searchText: String
    @Binding var sortOption: PokemonSortOption
    @Binding var selectedRegion: PokemonRegion
    @Binding var selectedFormFilter: PokemonFormFilter
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
        selectedRegion != .all || selectedGame != nil || selectedFormFilter != .all
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

                    Picker("Form", selection: $selectedFormFilter) {
                        ForEach(PokemonFormFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
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

                if selectedRegion != .all || selectedGame != nil || selectedFormFilter != .all {
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
                    SectionIndexBar(entries: indexEntries, verticalLabels: indexLabelsAreVertical) { targetID in
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

    // Only the region labels are rotated vertical; alphabet letters and numbers stay horizontal.
    private var indexLabelsAreVertical: Bool {
        sortOption == .pokedexNumber && selectedRegion == .all && selectedGame == nil
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
                if selectedFormFilter != .all {
                    FilterChip(title: selectedFormFilter.title, systemImage: "sparkles") {
                        selectedFormFilter = .all
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

private struct RegionSection: Identifiable {
    let region: PokemonRegion
    var pokemon: [PokemonSummary]
    var id: PokemonRegion { region }
}
