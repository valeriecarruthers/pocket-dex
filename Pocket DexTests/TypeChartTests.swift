//
//  TypeChartTests.swift
//  Pocket DexTests
//
//  Verifies the type-effectiveness chart. Beyond spot-checking well-known matchups, the
//  structural tests guarantee the derived defensive lookups stay in lock-step with the
//  offensive source of truth — so a future edit to one can't silently desync the other.
//

import Testing
@testable import Pocket_Dex

struct TypeChartTests {

    // MARK: - Offensive spot checks (well-known matchups)

    @Test("Super-effective matchups deal 2× damage", arguments: [
        (PokemonType.water, PokemonType.fire),
        (.fire, .grass),
        (.electric, .water),
        (.grass, .rock),
        (.ice, .dragon),
        (.fighting, .steel),
        (.fairy, .dragon),
        (.ground, .electric)
    ])
    func superEffective(attacker: PokemonType, defender: PokemonType) {
        #expect(attacker.attackMultiplier(against: defender) == 2)
    }

    @Test("Resisted matchups deal ½× damage", arguments: [
        (PokemonType.fire, PokemonType.water),
        (.water, .grass),
        (.grass, .steel),
        (.normal, .rock),
        (.bug, .fairy)
    ])
    func notVeryEffective(attacker: PokemonType, defender: PokemonType) {
        #expect(attacker.attackMultiplier(against: defender) == 0.5)
    }

    @Test("Immunities deal 0× damage", arguments: [
        (PokemonType.normal, PokemonType.ghost),
        (.ghost, .normal),
        (.electric, .ground),
        (.ground, .flying),
        (.fighting, .ghost),
        (.psychic, .dark),
        (.poison, .steel),
        (.dragon, .fairy)
    ])
    func immunities(attacker: PokemonType, defender: PokemonType) {
        #expect(attacker.attackMultiplier(against: defender) == 0)
    }

    @Test("Unlisted matchups are neutral (1×)")
    func neutral() {
        #expect(PokemonType.normal.attackMultiplier(against: .water) == 1)
        #expect(PokemonType.fire.attackMultiplier(against: .electric) == 1)
    }

    // MARK: - Structural integrity

    @Test("All 18 types are represented")
    func allTypesPresent() {
        #expect(PokemonType.allCases.count == 18)
    }

    // A defender must not appear in more than one of an attacker's offensive buckets.
    @Test("Offensive buckets are mutually exclusive", arguments: PokemonType.allCases)
    func offensiveBucketsDisjoint(type: PokemonType) {
        let superEffective = Set(type.superEffectiveAgainst)
        let resisted = Set(type.notVeryEffectiveAgainst)
        let immune = Set(type.noEffectAgainst)
        #expect(superEffective.isDisjoint(with: resisted))
        #expect(superEffective.isDisjoint(with: immune))
        #expect(resisted.isDisjoint(with: immune))
    }

    // The defensive lookups must agree with the offensive chart for every possible pairing.
    @Test("Defensive lookups mirror the offensive chart", arguments: PokemonType.allCases)
    func defensiveMirrorsOffensive(defender: PokemonType) {
        for attacker in PokemonType.allCases {
            let multiplier = attacker.attackMultiplier(against: defender)
            #expect(defender.weakTo.contains(attacker) == (multiplier == 2))
            #expect(defender.resists.contains(attacker) == (multiplier == 0.5))
            #expect(defender.immuneTo.contains(attacker) == (multiplier == 0))
        }
    }

    // MARK: - Presentation helpers

    @Test("Grid header abbreviations are unique")
    func uniqueAbbreviations() {
        let abbreviations = Set(PokemonType.allCases.map(\.abbreviation))
        #expect(abbreviations.count == PokemonType.allCases.count)
    }

    @Test("Effectiveness multipliers format to compact labels", arguments: [
        (0.0, "0"), (0.5, "½"), (1.0, "1"), (2.0, "2")
    ])
    func effectivenessLabels(value: Double, expected: String) {
        #expect(PokemonType.effectivenessLabel(value) == expected)
    }
}
