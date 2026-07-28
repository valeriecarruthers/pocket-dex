/**
 * build-dataset.mjs
 *
 * Generates the static Pokedex dataset that the web app is built from.
 *
 * Source of truth is the PokeAPI/api-data repository — the same static JSON that
 * backs pokeapi.co, but served from raw.githubusercontent.com and, crucially,
 * pinned to an exact commit. Pinning means a rebuild is byte-reproducible and
 * "has upstream changed?" is a single SHA comparison rather than a diff of a
 * thousand list endpoints. That check is what the `pokedex-sync` skill runs.
 *
 * Usage:
 *   node scripts/build-dataset.mjs                 # pin to current master
 *   POKEAPI_REF=<sha> node scripts/build-dataset.mjs
 *   node scripts/build-dataset.mjs --check         # report drift, write nothing
 */

import { mkdir, writeFile, rm, readFile } from "node:fs/promises";
import { execFile } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT_DIR = path.join(ROOT, "src", "data");
const SPECIES_DIR = path.join(OUT_DIR, "species");

const SOURCE_REPO = "PokeAPI/api-data";
const CONCURRENCY = Number(process.env.FETCH_CONCURRENCY ?? 24);
const CHECK_ONLY = process.argv.includes("--check");

// ---------------------------------------------------------------------------
// Formatting helpers — ports of String+Formatting.swift
// ---------------------------------------------------------------------------

/** "zapdos-galar" -> "Zapdos Galar" */
function displayName(raw) {
  return raw
    .split("-")
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

/** PokeAPI embeds hard line breaks and form feeds in its free text. */
function cleanText(raw) {
  return raw
    .replace(/\n/g, " ")
    .replace(/\f/g, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
}

/** Trailing numeric path component of a PokeAPI resource URL. */
function idFromURL(url) {
  const match = /\/(\d+)\/?$/.exec(url);
  return match ? Number(match[1]) : null;
}

// ---------------------------------------------------------------------------
// Fetching
// ---------------------------------------------------------------------------

async function resolveRef() {
  if (process.env.POKEAPI_REF) return process.env.POKEAPI_REF;

  const { stdout } = await execFileAsync(
    "git",
    ["ls-remote", `https://github.com/${SOURCE_REPO}.git`, "master"],
    { timeout: 60_000 },
  );
  const sha = stdout.trim().split(/\s+/)[0];
  if (!/^[0-9a-f]{40}$/.test(sha)) {
    throw new Error(`Could not resolve ${SOURCE_REPO}@master (got: ${stdout.trim()})`);
  }
  return sha;
}

function makeFetcher(ref) {
  const base = `https://raw.githubusercontent.com/${SOURCE_REPO}/${ref}/data/api/v2`;
  let completed = 0;

  return async function getJSON(resourcePath, { optional = false } = {}) {
    const url = `${base}/${resourcePath}/index.json`;

    for (let attempt = 0; attempt < 4; attempt += 1) {
      try {
        const response = await fetch(url, { headers: { Accept: "application/json" } });

        if (response.status === 404 && optional) return null;
        if (!response.ok) throw new Error(`HTTP ${response.status}`);

        const json = await response.json();
        completed += 1;
        if (completed % 250 === 0) process.stderr.write(`  …${completed} resources\n`);
        return json;
      } catch (error) {
        if (attempt === 3) {
          if (optional) return null;
          throw new Error(`Failed to fetch ${resourcePath}: ${error.message}`);
        }
        await new Promise((resolve) => setTimeout(resolve, 400 * (attempt + 1)));
      }
    }
    return null;
  };
}

/** Runs `worker` over `items` with a bounded number of in-flight promises. */
async function mapPool(items, worker, limit = CONCURRENCY) {
  const results = new Array(items.length);
  let cursor = 0;

  async function run() {
    while (cursor < items.length) {
      const index = cursor;
      cursor += 1;
      results[index] = await worker(items[index], index);
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, run));
  return results;
}

// ---------------------------------------------------------------------------
// Derivations — ports of PokeAPIClient.swift / PokeAPIResponses.swift
// ---------------------------------------------------------------------------

function englishFlavorText(species) {
  const entry = species.flavor_text_entries?.find((e) => e.language.name === "en");
  return entry ? cleanText(entry.flavor_text) : null;
}

function englishGenus(species) {
  return species.genera?.find((g) => g.language.name === "en")?.genus ?? null;
}

function abilityDescription(ability) {
  const effect = ability.effect_entries?.find((e) => e.language.name === "en");
  if (effect) return cleanText(effect.short_effect || effect.effect || "");

  const flavor = ability.flavor_text_entries?.find((e) => e.language.name === "en");
  return flavor ? cleanText(flavor.flavor_text) : null;
}

/** "zapdos-galar" with species "zapdos" -> "Galar" */
function formLabel(formName, speciesName) {
  if (formName === speciesName) return "Default";
  if (formName.startsWith(`${speciesName}-`)) {
    return displayName(formName.slice(speciesName.length + 1));
  }
  return displayName(formName);
}

/** Port of PokeAPIEvolutionDetail.summary — first matching condition wins. */
function evolutionRequirement(detail) {
  if (!detail) return null;
  if (detail.min_level != null) return `Level ${detail.min_level}`;
  if (detail.item) return displayName(detail.item.name);
  if (detail.min_happiness != null) return `Friendship ${detail.min_happiness}`;
  if (detail.time_of_day) return displayName(detail.time_of_day);
  if (detail.trigger) return displayName(detail.trigger.name);
  return null;
}

function buildEvolutionNode(link) {
  return {
    id: idFromURL(link.species.url) ?? 0,
    name: link.species.name,
    requirement: evolutionRequirement(link.evolution_details?.[0]),
    children: (link.evolves_to ?? []).map(buildEvolutionNode),
  };
}

function bestArtwork(sprites) {
  return {
    regular: sprites?.other?.["official-artwork"]?.front_default ?? sprites?.front_default ?? null,
    shiny: sprites?.other?.["official-artwork"]?.front_shiny ?? sprites?.front_shiny ?? null,
  };
}

/** The subset of a `pokemon` resource that varies between forms. */
function makeFormDetail(pokemon) {
  const artwork = bestArtwork(pokemon.sprites);

  return {
    regularImageURL: artwork.regular,
    shinyImageURL: artwork.shiny,
    types: [...pokemon.types].sort((a, b) => a.slot - b.slot).map((t) => t.type.name),
    abilities: [...pokemon.abilities]
      .sort((a, b) => a.slot - b.slot)
      .map((a) => ({ name: a.ability.name, isHidden: a.is_hidden })),
    height: pokemon.height,
    weight: pokemon.weight,
    baseExperience: pokemon.base_experience ?? null,
    // Not surfaced by the iOS app, but free in this payload and expected of a web Pokedex.
    stats: pokemon.stats.map((s) => ({ name: s.stat.name, value: s.base_stat })),
  };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const ref = await resolveRef();
  process.stderr.write(`Source: ${SOURCE_REPO}@${ref}\n`);

  if (CHECK_ONLY) {
    let current = null;
    try {
      current = JSON.parse(await readFile(path.join(OUT_DIR, "meta.json"), "utf8"));
    } catch {
      process.stdout.write(
        JSON.stringify({ upToDate: false, reason: "no-dataset", upstreamRef: ref }, null, 2) + "\n",
      );
      process.exit(1);
    }

    const upToDate = current.sourceRef === ref;
    process.stdout.write(
      JSON.stringify(
        {
          upToDate,
          reason: upToDate ? "unchanged" : "upstream-moved",
          localRef: current.sourceRef,
          upstreamRef: ref,
          generatedAt: current.generatedAt,
        },
        null,
        2,
      ) + "\n",
    );
    process.exit(upToDate ? 0 : 1);
  }

  const getJSON = makeFetcher(ref);

  // --- Species list -------------------------------------------------------
  process.stderr.write("Fetching species list…\n");
  // The static mirror serves complete, unpaginated list resources.
  const speciesIndex = await getJSON("pokemon-species");
  const speciesRefs = speciesIndex.results
    .map((r) => ({ id: idFromURL(r.url), name: r.name }))
    .filter((r) => r.id != null)
    .sort((a, b) => a.id - b.id);

  process.stderr.write(`Fetching ${speciesRefs.length} species…\n`);
  const speciesResources = await mapPool(speciesRefs, (r) =>
    getJSON(`pokemon-species/${r.id}`),
  );

  // --- Varieties (one `pokemon` resource per form) -------------------------
  const varietyIds = new Set();
  for (const species of speciesResources) {
    for (const variety of species.varieties ?? []) {
      const id = idFromURL(variety.pokemon.url);
      if (id != null) varietyIds.add(id);
    }
  }

  process.stderr.write(`Fetching ${varietyIds.size} varieties…\n`);
  const varietyList = [...varietyIds];
  const varietyResources = await mapPool(varietyList, (id) => getJSON(`pokemon/${id}`));
  const varietyById = new Map(varietyList.map((id, i) => [id, varietyResources[i]]));

  // --- Evolution chains ----------------------------------------------------
  const chainIds = new Set();
  for (const species of speciesResources) {
    const id = species.evolution_chain ? idFromURL(species.evolution_chain.url) : null;
    if (id != null) chainIds.add(id);
  }

  process.stderr.write(`Fetching ${chainIds.size} evolution chains…\n`);
  const chainList = [...chainIds];
  const chainResources = await mapPool(chainList, (id) =>
    getJSON(`evolution-chain/${id}`, { optional: true }),
  );
  const chainById = new Map(chainList.map((id, i) => [id, chainResources[i]]));

  // --- Abilities -----------------------------------------------------------
  const abilityIndex = await getJSON("ability");
  const abilityRefs = abilityIndex.results
    .map((r) => ({ id: idFromURL(r.url), name: r.name }))
    .filter((r) => r.id != null);

  process.stderr.write(`Fetching ${abilityRefs.length} abilities…\n`);
  const abilityResources = await mapPool(abilityRefs, (r) =>
    getJSON(`ability/${r.id}`, { optional: true }),
  );

  const abilities = {};
  abilityRefs.forEach((ref_, i) => {
    const resource = abilityResources[i];
    if (!resource) return;
    abilities[ref_.name] = {
      displayName: displayName(ref_.name),
      description: abilityDescription(resource),
    };
  });

  // --- Games (version group -> pokedexes -> species) -----------------------
  process.stderr.write("Fetching games…\n");
  const versionGroupIndex = await getJSON("version-group");
  const versionGroupRefs = versionGroupIndex.results
    .map((r) => ({ id: idFromURL(r.url), name: r.name }))
    .filter((r) => r.id != null)
    .sort((a, b) => a.id - b.id);

  const versionGroups = await mapPool(versionGroupRefs, (r) => getJSON(`version-group/${r.id}`));

  const pokedexIds = new Set();
  versionGroups.forEach((group) => {
    for (const dex of group.pokedexes ?? []) {
      const id = idFromURL(dex.url);
      if (id != null) pokedexIds.add(id);
    }
  });

  const pokedexList = [...pokedexIds];
  const pokedexResources = await mapPool(pokedexList, (id) =>
    getJSON(`pokedex/${id}`, { optional: true }),
  );
  const pokedexSpecies = new Map(
    pokedexList.map((id, i) => {
      const resource = pokedexResources[i];
      const ids = (resource?.pokemon_entries ?? [])
        .map((entry) => idFromURL(entry.pokemon_species.url))
        .filter((v) => v != null);
      return [id, ids];
    }),
  );

  const games = versionGroupRefs.map((ref_, i) => {
    const group = versionGroups[i];
    const speciesIds = new Set();
    for (const dex of group.pokedexes ?? []) {
      const id = idFromURL(dex.url);
      for (const speciesId of pokedexSpecies.get(id) ?? []) speciesIds.add(speciesId);
    }
    return {
      id: ref_.id,
      name: ref_.name,
      speciesIds: [...speciesIds].sort((a, b) => a - b),
    };
  });

  // --- Assemble ------------------------------------------------------------
  process.stderr.write("Assembling dataset…\n");

  await rm(SPECIES_DIR, { recursive: true, force: true });
  await mkdir(SPECIES_DIR, { recursive: true });

  const index = [];

  for (let i = 0; i < speciesRefs.length; i += 1) {
    const { id, name } = speciesRefs[i];
    const species = speciesResources[i];

    const varieties = species.varieties ?? [];
    const defaultVariety = varieties.find((v) => v.is_default) ?? varieties[0];
    const defaultPokemon = defaultVariety ? varietyById.get(idFromURL(defaultVariety.pokemon.url)) : null;
    if (!defaultPokemon) continue;

    const forms = varieties.map((variety) => {
      const varietyId = idFromURL(variety.pokemon.url);
      const pokemon = varietyById.get(varietyId);
      return {
        name: variety.pokemon.name,
        label: formLabel(variety.pokemon.name, name),
        isDefault: variety.is_default,
        detail: pokemon ? makeFormDetail(pokemon) : null,
      };
    });

    const chainId = species.evolution_chain ? idFromURL(species.evolution_chain.url) : null;
    const chain = chainId != null ? chainById.get(chainId) : null;

    const defaultForm = makeFormDetail(defaultPokemon);
    const hasMega = varieties.some((v) => v.pokemon.name.includes("-mega"));
    const hasGigantamax = varieties.some((v) => v.pokemon.name.includes("-gmax"));

    // Gallery index entry — kept lean because the whole array ships to the client.
    index.push({
      id,
      name,
      displayName: displayName(name),
      types: defaultForm.types,
      hasAlternateForms: varieties.length > 1,
      hasMega,
      hasGigantamax,
    });

    // Per-species detail — read from disk at build time, never bundled.
    await writeFile(
      path.join(SPECIES_DIR, `${id}.json`),
      JSON.stringify({
        id,
        name,
        displayName: displayName(name),
        flavorText: englishFlavorText(species),
        genus: englishGenus(species),
        habitat: species.habitat ? displayName(species.habitat.name) : null,
        evolutionTree: chain?.chain ? [buildEvolutionNode(chain.chain)] : [],
        forms,
        defaultForm,
      }),
    );
  }

  const meta = {
    sourceRepo: SOURCE_REPO,
    sourceRef: ref,
    generatedAt: new Date().toISOString(),
    counts: {
      species: index.length,
      varieties: varietyIds.size,
      evolutionChains: chainIds.size,
      abilities: Object.keys(abilities).length,
      games: games.length,
    },
  };

  await writeFile(path.join(OUT_DIR, "pokedex.json"), JSON.stringify(index));
  await writeFile(path.join(OUT_DIR, "abilities.json"), JSON.stringify(abilities));
  await writeFile(path.join(OUT_DIR, "games.json"), JSON.stringify(games));
  await writeFile(path.join(OUT_DIR, "meta.json"), JSON.stringify(meta, null, 2) + "\n");

  process.stderr.write(`\nDone. ${JSON.stringify(meta.counts)}\n`);
}

main().catch((error) => {
  process.stderr.write(`\n${error.stack}\n`);
  process.exit(1);
});
