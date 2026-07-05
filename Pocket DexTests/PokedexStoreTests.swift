//
//  PokedexStoreTests.swift
//  Pocket DexTests
//
//  Covers the SwiftData reference store: the deterministic upserts behind PokedexStore, the
//  record ↔ value-type mappings the views rely on, and the refresh-cadence policy.
//

import Testing
import SwiftData
import Foundation
@testable import Pocket_Dex

@MainActor
struct PokedexStoreTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: SpeciesRecord.self, GameRecord.self, PokemonDetailRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // Reads through a fresh context that queries the shared in-memory store directly, so we
    // never depend on cross-context auto-merge timing or hop onto the main actor.
    private func fetchAll<T: PersistentModel>(_ type: T.Type, from container: ModelContainer) throws -> [T] {
        try ModelContext(container).fetch(FetchDescriptor<T>())
    }

    private static func sampleDetail() -> PokemonDetail {
        let summary = PokemonSummary(id: 1, name: "bulbasaur", url: URL(string: "https://x/1")!)
        let form = PokemonFormDetail(
            regularImageURL: nil,
            shinyImageURL: nil,
            types: ["grass", "poison"],
            abilities: [PokemonAbility(name: "overgrow", isHidden: false)],
            height: 7,
            weight: 69,
            baseExperience: 64
        )
        let evolution = EvolutionNode(
            id: 1, name: "bulbasaur", requirement: nil,
            children: [EvolutionNode(id: 2, name: "ivysaur", requirement: "Level 16", children: [])]
        )
        let defaultForm = PokemonForm(name: "bulbasaur", url: URL(string: "https://x/1")!, isDefault: true, label: "Default")
        return PokemonDetail(
            summary: summary,
            pokedexNames: ["kanto"],
            flavorText: "A strange seed.",
            genus: "Seed Pokémon",
            habitat: "grassland",
            evolutionTree: [evolution],
            forms: [defaultForm],
            defaultForm: form
        )
    }

    // MARK: - Upserts

    @Test("Syncing species upserts without duplicating existing ids")
    func syncSpeciesUpserts() async throws {
        let container = try makeContainer()
        let store = PokedexStore(modelContainer: container)

        let bulbasaur = PokemonSummary(id: 1, name: "bulbasaur", url: URL(string: "https://x/1")!)
        let charmander = PokemonSummary(id: 4, name: "charmander", url: URL(string: "https://x/4")!)
        try await store.sync(species: [bulbasaur, charmander])
        #expect(try fetchAll(SpeciesRecord.self, from: container).count == 2)

        // Re-sync: rename id 1, keep id 4, add id 7 → 3 total, no duplicates, name updated.
        let renamed = PokemonSummary(id: 1, name: "bulbasaur-x", url: URL(string: "https://x/1b")!)
        let squirtle = PokemonSummary(id: 7, name: "squirtle", url: URL(string: "https://x/7")!)
        try await store.sync(species: [renamed, charmander, squirtle])

        let all = try fetchAll(SpeciesRecord.self, from: container)
        #expect(all.count == 3)
        #expect(all.first { $0.id == 1 }?.name == "bulbasaur-x")
        #expect(all.first { $0.id == 1 }?.url == URL(string: "https://x/1b")!)
    }

    @Test("Syncing games upserts without duplicating existing ids")
    func syncGamesUpserts() async throws {
        let container = try makeContainer()
        let store = PokedexStore(modelContainer: container)

        try await store.sync(games: [PokemonGame(id: 1, name: "red-blue", url: URL(string: "https://g/1")!)])
        try await store.sync(games: [
            PokemonGame(id: 1, name: "red-blue", url: URL(string: "https://g/1")!),
            PokemonGame(id: 2, name: "gold-silver", url: URL(string: "https://g/2")!)
        ])

        #expect(try fetchAll(GameRecord.self, from: container).count == 2)
    }

    // MARK: - Details

    @Test("Saving a detail round-trips nested data and upserts on re-save")
    func saveDetailRoundTrips() async throws {
        let container = try makeContainer()
        let store = PokedexStore(modelContainer: container)
        let detail = Self.sampleDetail()

        try await store.saveDetail(detail, gameAppearanceIDs: [1, 2])

        let records = try fetchAll(PokemonDetailRecord.self, from: container)
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.flavorText == "A strange seed.")
        #expect(record.gameAppearanceIDs == [1, 2])
        #expect(record.evolutionTree.first?.children.first?.name == "ivysaur")
        #expect(record.forms.count == 1)

        // Mapping back reconstructs the value type the views use.
        let mapped = PokemonDetail(record, summary: detail.summary)
        #expect(mapped.genus == "Seed Pokémon")
        #expect(mapped.defaultForm.types == ["grass", "poison"])

        // Re-save with nil ids updates in place and preserves the previously cached game ids.
        try await store.saveDetail(detail, gameAppearanceIDs: nil)
        let after = try fetchAll(PokemonDetailRecord.self, from: container)
        #expect(after.count == 1)
        #expect(after.first?.gameAppearanceIDs == [1, 2])
    }

    @Test("Clearing empties every reference model")
    func clearEmptiesStore() async throws {
        let container = try makeContainer()
        let store = PokedexStore(modelContainer: container)
        try await store.sync(species: [PokemonSummary(id: 1, name: "bulbasaur", url: URL(string: "https://x/1")!)])
        try await store.saveDetail(Self.sampleDetail(), gameAppearanceIDs: nil)

        try await store.clear()

        #expect(try fetchAll(SpeciesRecord.self, from: container).isEmpty)
        #expect(try fetchAll(PokemonDetailRecord.self, from: container).isEmpty)
    }

    // MARK: - Mapping

    @Test("A species record maps to a summary with its derived properties")
    func speciesRecordMapsToSummary() {
        let record = SpeciesRecord(id: 6, name: "charizard", url: URL(string: "https://x/6")!)
        let summary = PokemonSummary(record)
        #expect(summary.id == 6)
        #expect(summary.displayName == "Charizard")
        #expect(summary.region.contains(6))
        #expect(summary.artworkURL?.absoluteString.contains("/6.png") == true)
    }

    // MARK: - Refresh policy

    @Test("Refresh policy: empty or missing timestamp refreshes; fresh skips", arguments: [
        (true, nil as Date?, true),
        (false, nil as Date?, true),
        (false, Date.now, false)
    ])
    func refreshPolicy(isEmpty: Bool, lastRefresh: Date?, expected: Bool) {
        #expect(PokedexRefresh.shouldRefreshList(isEmpty: isEmpty, lastRefresh: lastRefresh) == expected)
    }

    @Test("Refresh policy: a timestamp older than the TTL triggers a refresh")
    func refreshPolicyStale() {
        let stale = Date.now.addingTimeInterval(-PokedexRefresh.listTTL - 1)
        #expect(PokedexRefresh.shouldRefreshList(isEmpty: false, lastRefresh: stale) == true)
    }
}
