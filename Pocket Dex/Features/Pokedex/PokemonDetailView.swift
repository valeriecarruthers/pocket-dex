//
//  PokemonDetailView.swift
//  Pocket Dex
//
//  The full detail screen: hero artwork, form switcher, profile, game appearances, and evolution.
//

import SwiftUI
import SwiftData

struct PokemonDetailView: View {
    let pokemon: PokemonSummary
    let previousPokemon: PokemonSummary?
    let nextPokemon: PokemonSummary?
    let games: [PokemonGame]
    @Binding var showingShiny: Bool
    let selectPokemon: (PokemonSummary) -> Void
    let selectPokemonID: (Int) -> Void

    @State private var detail: PokemonDetail?
    @State private var isLoading = false
    @State private var loadingError: String?
    @State private var gameAppearances: [PokemonGame]?
    @State private var selectedForm: PokemonForm?
    @State private var formCache: [String: PokemonFormDetail] = [:]
    @State private var isLoadingForm = false

    @Environment(\.modelContext) private var modelContext

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
                    let form = activeForm(for: detail)
                    PokemonHeroView(detail: detail, form: form, formLabel: activeFormLabel, showingShiny: $showingShiny)
                    if detail.forms.count > 1 {
                        PokemonFormSwitcher(
                            forms: detail.forms,
                            selected: selectedForm,
                            isLoading: isLoadingForm
                        ) { form in
                            Task { await selectForm(form) }
                        }
                    }
                    PokemonProfileView(detail: detail, form: form)
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

    private func activeForm(for detail: PokemonDetail) -> PokemonFormDetail {
        guard let selectedForm, !selectedForm.isDefault else { return detail.defaultForm }
        return formCache[selectedForm.name] ?? detail.defaultForm
    }

    private var activeFormLabel: String? {
        guard let selectedForm, !selectedForm.isDefault else { return nil }
        return selectedForm.label
    }

    private func selectForm(_ form: PokemonForm) async {
        selectedForm = form
        guard !form.isDefault, formCache[form.name] == nil else { return }

        isLoadingForm = true
        defer { isLoadingForm = false }
        if let loaded = try? await PokeAPIClient.shared.fetchFormDetail(url: form.url) {
            formCache[form.name] = loaded
        }
    }

    private func loadDetail() async {
        loadingError = nil
        gameAppearances = nil
        selectedForm = nil

        // Store first: a persisted record renders instantly and works fully offline.
        if let record = cachedDetailRecord() {
            let cached = PokemonDetail(record, summary: pokemon)
            detail = cached
            selectedForm = cached.forms.first { $0.isDefault } ?? cached.forms.first
            await resolveGameAppearances(for: cached, cachedIDs: record.gameAppearanceIDs)
            return
        }

        // Cache miss: fetch from the network, show it, and persist it forever.
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await PokeAPIClient.shared.fetchPokemonDetail(for: pokemon)
            detail = fetched
            selectedForm = fetched.forms.first { $0.isDefault } ?? fetched.forms.first
            let store = PokedexStore(modelContainer: modelContext.container)
            try? await store.saveDetail(fetched, gameAppearanceIDs: nil)
            await resolveGameAppearances(for: fetched, cachedIDs: nil)
        } catch {
            loadingError = error.localizedDescription
            detail = nil
        }
    }

    // Reads any persisted detail for this Pokemon from the main context.
    private func cachedDetailRecord() -> PokemonDetailRecord? {
        let id = pokemon.id
        let descriptor = FetchDescriptor<PokemonDetailRecord>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    // Fills the games section. Uses cached appearance ids when present (offline, and skips the
    // app's heaviest call — fetchGamesForSpecies); otherwise resolves them over the network and
    // backfills the store so the next visit is instant.
    private func resolveGameAppearances(for detail: PokemonDetail, cachedIDs: [Int]?) async {
        if let cachedIDs {
            let byID = Dictionary(games.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            gameAppearances = cachedIDs.compactMap { byID[$0] }.sorted { $0.id < $1.id }
            return
        }

        guard let resolved = try? await PokeAPIClient.shared.fetchGamesForSpecies(pokedexNames: detail.pokedexNames) else {
            gameAppearances = []
            return
        }
        gameAppearances = resolved
        let store = PokedexStore(modelContainer: modelContext.container)
        try? await store.saveDetail(detail, gameAppearanceIDs: resolved.map(\.id))
    }
}

private struct PokemonHeroView: View {
    let detail: PokemonDetail
    let form: PokemonFormDetail
    let formLabel: String?
    @Binding var showingShiny: Bool

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var activeImageURL: URL? {
        showingShiny ? form.shinyImageURL : form.regularImageURL
    }

    private var displayName: String {
        if let formLabel {
            return "\(detail.summary.displayName) (\(formLabel))"
        }
        return detail.summary.displayName
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
        form.types.first.map(Color.pokemonType)
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

                    Text(displayName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    if let genus = detail.genus {
                        Text(genus)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    TypeChips(types: form.types)
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

private struct PokemonFormSwitcher: View {
    let forms: [PokemonForm]
    let selected: PokemonForm?
    let isLoading: Bool
    let onSelect: (PokemonForm) -> Void

    var body: some View {
        DetailSection(title: "Forms") {
            FlowLayout(spacing: 8) {
                ForEach(forms) { form in
                    let isSelected = selected == form
                    Button {
                        onSelect(form)
                    } label: {
                        HStack(spacing: 5) {
                            Text(form.label)
                                .fontWeight(.medium)
                            if isLoading && isSelected {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                        }
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            (isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.12)),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                }
            }
        }
    }
}

private struct PokemonProfileView: View {
    let detail: PokemonDetail
    let form: PokemonFormDetail

    var body: some View {
        DetailSection(title: "Profile") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                StatCard(title: "Region", value: detail.summary.region.name, systemImage: "map")
                StatCard(title: "Height", value: form.heightText, systemImage: "ruler")
                StatCard(title: "Weight", value: form.weightText, systemImage: "scalemass")
                StatCard(title: "Base XP", value: form.baseExperienceText, systemImage: "star")
                StatCard(title: "Habitat", value: detail.habitat ?? "Unknown", systemImage: "leaf")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Abilities")
                    .font(.headline)
                FlowLayout(spacing: 8) {
                    ForEach(form.abilities, id: \.self) { ability in
                        AbilityChip(ability: ability)
                    }
                }
            }
        }
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
