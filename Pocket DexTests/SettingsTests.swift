//
//  SettingsTests.swift
//  Pocket DexTests
//
//  Covers the logic behind the Settings tab: the appearance-to-ColorScheme mapping that
//  RootView relies on, and the PokeAPI disk cache's size/clear behavior surfaced in Storage.
//

import Testing
import SwiftUI
@testable import Pocket_Dex

struct AppAppearanceTests {

    @Test("Appearance maps to the correct ColorScheme", arguments: [
        (AppAppearance.system, ColorScheme?.none),
        (.light, .light),
        (.dark, .dark)
    ])
    func colorSchemeMapping(appearance: AppAppearance, expected: ColorScheme?) {
        #expect(appearance.colorScheme == expected)
    }

    @Test("Raw values round-trip through storage", arguments: AppAppearance.allCases)
    func rawValueRoundTrip(appearance: AppAppearance) {
        #expect(AppAppearance(rawValue: appearance.rawValue) == appearance)
    }

    @Test("All three appearance options are offered")
    func allCasesPresent() {
        #expect(AppAppearance.allCases.count == 3)
    }

    // The storage key is a stable contract between SettingsView and RootView: changing it
    // would orphan every user's saved preference, so pin it down.
    @Test("Storage key is stable")
    func storageKeyStable() {
        #expect(AppAppearance.storageKey == "appearance")
    }

    @Test("Every appearance has a non-empty label", arguments: AppAppearance.allCases)
    func labelsPresent(appearance: AppAppearance) {
        #expect(!appearance.label.isEmpty)
    }
}

// Serialized because these tests share the on-disk singleton; running them in parallel
// would let one test's clear() race another's size check.
@Suite(.serialized)
struct PokeAPIDiskCacheTests {

    @Test("Reported size grows on save and returns to zero on clear")
    func sizeAndClearRoundTrip() async throws {
        let cache = PokeAPIDiskCache.shared
        let url = URL(string: "https://pocket-dex.test/\(UUID().uuidString)")!
        let payload = Data(repeating: 0xAB, count: 1024)

        // Start from a known-empty state.
        try await cache.clear()
        #expect(try await cache.sizeBytes() == 0)

        try await cache.save(payload, for: url)
        #expect(try await cache.sizeBytes() >= payload.count)

        try await cache.clear()
        #expect(try await cache.sizeBytes() == 0)
    }

    @Test("Clearing an already-empty cache is a no-op")
    func clearWhenEmpty() async throws {
        let cache = PokeAPIDiskCache.shared
        try await cache.clear()
        try await cache.clear()
        #expect(try await cache.sizeBytes() == 0)
    }
}
