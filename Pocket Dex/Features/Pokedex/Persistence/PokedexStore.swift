//
//  PokedexStore.swift
//  Pocket Dex
//
//  Background writer for the reference store. Reads happen on the main context (via @Query
//  in the views); all writes funnel through this @ModelActor so the ~1300-species sync and
//  detail saves never block the main thread. Only Sendable value types cross the actor
//  boundary — we never hand @Model objects back out.
//

import Foundation
import SwiftData

@ModelActor
actor PokedexStore {

    // MARK: Writes

    /// Persists a fetched detail forever, upserting on the species id. Called after a
    /// PokemonDetailView cache miss; game appearances are backfilled once resolved.
    func saveDetail(_ detail: PokemonDetail, gameAppearanceIDs: [Int]?) throws {
        let id = detail.summary.id
        let existing = try modelContext.fetch(
            FetchDescriptor<PokemonDetailRecord>(predicate: #Predicate { $0.id == id })
        )

        let record: PokemonDetailRecord
        if let found = existing.first {
            record = found
        } else {
            record = PokemonDetailRecord(id: id, defaultForm: detail.defaultForm)
            modelContext.insert(record)
        }
        record.apply(detail, gameAppearanceIDs: gameAppearanceIDs)
        try modelContext.save()
    }

    /// Empties the reference store (backs Settings → Clear Cache). The gallery repopulates on
    /// its next appearance via the isEmpty path.
    func clear() throws {
        try modelContext.delete(model: SpeciesRecord.self)
        try modelContext.delete(model: GameRecord.self)
        try modelContext.delete(model: PokemonDetailRecord.self)
        try modelContext.save()
    }

    // MARK: Deterministic upserts (network-free, unit-testable)

    func sync(species summaries: [PokemonSummary]) throws {
        let existing = try modelContext.fetch(FetchDescriptor<SpeciesRecord>())
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for summary in summaries {
            if let record = byID[summary.id] {
                record.name = summary.name
                record.url = summary.url
            } else {
                let record = SpeciesRecord(id: summary.id, name: summary.name, url: summary.url)
                modelContext.insert(record)
                byID[summary.id] = record
            }
        }
        try modelContext.save()
    }

    func sync(games: [PokemonGame]) throws {
        let existing = try modelContext.fetch(FetchDescriptor<GameRecord>())
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for game in games {
            if let record = byID[game.id] {
                record.name = game.name
                record.url = game.url
            } else {
                let record = GameRecord(id: game.id, name: game.name, url: game.url)
                modelContext.insert(record)
                byID[game.id] = record
            }
        }
        try modelContext.save()
    }
}

/// Decides when the (essentially static) reference list is worth re-fetching. PokeAPI data
/// changes at most quarterly, so we only refresh when the store is empty or the cache is old.
enum PokedexRefresh {
    static let listTTL: TimeInterval = 60 * 60 * 24 * 30   // 30 days
    static let lastListRefreshKey = "pokedex.lastListRefresh"

    static func shouldRefreshList(isEmpty: Bool, lastRefresh: Date?, now: Date = .now) -> Bool {
        if isEmpty { return true }
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= listTTL
    }
}
