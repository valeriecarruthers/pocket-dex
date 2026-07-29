/**
 * Verifies the hand-ported type chart against PokeAPI's own damage relations.
 *
 * The chart in src/lib/pokemon-type.ts is written out by hand (as it is in the
 * Swift app) so the app needs no type data at runtime. This test is what makes
 * that safe: it checks all 324 matchups against upstream.
 *
 * Run: node --test tests/
 * Set OFFLINE=1 to skip the upstream comparison and run local invariants only.
 */

import assert from "node:assert/strict";
import test from "node:test";

import {
  POKEMON_TYPES,
  attackMultiplier,
  defensiveMultiplier,
  immuneTo,
  resists,
  weakTo,
} from "../src/lib/pokemon-type.ts";

const BASE =
  "https://raw.githubusercontent.com/PokeAPI/api-data/master/data/api/v2/type";

test("every type is covered exactly once", () => {
  assert.equal(POKEMON_TYPES.length, 18);
  assert.equal(new Set(POKEMON_TYPES).size, 18);
});

test("multipliers are always one of 0, 0.5, 1, 2", () => {
  for (const attacker of POKEMON_TYPES) {
    for (const defender of POKEMON_TYPES) {
      assert.ok(
        [0, 0.5, 1, 2].includes(attackMultiplier(attacker, defender)),
        `${attacker} -> ${defender}`,
      );
    }
  }
});

test("the defensive view is consistent with the offensive one", () => {
  for (const defender of POKEMON_TYPES) {
    for (const attacker of weakTo(defender)) {
      assert.equal(attackMultiplier(attacker, defender), 2);
    }
    for (const attacker of resists(defender)) {
      assert.equal(attackMultiplier(attacker, defender), 0.5);
    }
    for (const attacker of immuneTo(defender)) {
      assert.equal(attackMultiplier(attacker, defender), 0);
    }
  }
});

test("dual typings stack multiplicatively", () => {
  // Charizard: Rock hits both halves for 2x, Ground cannot touch a Flying type.
  assert.equal(defensiveMultiplier("rock", ["fire", "flying"]), 4);
  assert.equal(defensiveMultiplier("ground", ["fire", "flying"]), 0);
  assert.equal(defensiveMultiplier("grass", ["fire", "flying"]), 0.25);

  // Ferrothorn: the textbook 4x Fire weakness, immune to Poison via Steel.
  assert.equal(defensiveMultiplier("fire", ["grass", "steel"]), 4);
  assert.equal(defensiveMultiplier("poison", ["grass", "steel"]), 0);
});

test(
  "matches PokeAPI damage relations for all 324 matchups",
  { skip: process.env.OFFLINE === "1" ? "OFFLINE=1" : false },
  async () => {
    // Resources in the static mirror are addressed by id, so resolve names first.
    const indexResponse = await fetch(`${BASE}/index.json`);
    assert.ok(indexResponse.ok, `could not fetch type index: HTTP ${indexResponse.status}`);
    const { results } = await indexResponse.json();
    const idByName = new Map(
      results.map((entry) => [entry.name, /\/(\d+)\/?$/.exec(entry.url)?.[1]]),
    );

    const upstream = new Map();

    await Promise.all(
      POKEMON_TYPES.map(async (type) => {
        const id = idByName.get(type);
        assert.ok(id, `upstream has no type named ${type}`);

        const response = await fetch(`${BASE}/${id}/index.json`);
        assert.ok(response.ok, `could not fetch ${type}: HTTP ${response.status}`);
        const { damage_relations: relations } = await response.json();

        const expected = new Map();
        for (const { name } of relations.double_damage_to) expected.set(name, 2);
        for (const { name } of relations.half_damage_to) expected.set(name, 0.5);
        for (const { name } of relations.no_damage_to) expected.set(name, 0);
        upstream.set(type, expected);
      }),
    );

    const mismatches = [];
    for (const attacker of POKEMON_TYPES) {
      for (const defender of POKEMON_TYPES) {
        const expected = upstream.get(attacker).get(defender) ?? 1;
        const actual = attackMultiplier(attacker, defender);
        if (expected !== actual) {
          mismatches.push(`${attacker} -> ${defender}: expected ${expected}, got ${actual}`);
        }
      }
    }

    assert.deepEqual(mismatches, [], `\n${mismatches.join("\n")}`);
  },
);
