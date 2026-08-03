/**
 * report-dataset-changes.mjs
 *
 * Describes what actually changed between the committed dataset and the
 * regenerated one, in terms a person can act on.
 *
 * `git diff --stat` is useless here: the dataset is minified JSON on one line,
 * so it reports "1 file changed" whether a typo was fixed upstream or an entire
 * generation shipped. This turns the diff into species-level facts, and flags
 * the two cases that machines cannot finish on their own.
 *
 * Usage:
 *   node scripts/report-dataset-changes.mjs [--base HEAD]
 *
 * Writes Markdown to stdout. Exits 0 when nothing of substance changed, 1 when
 * something did, so a workflow can branch on it.
 */

import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const REL = "web/src/data/pokedex.json";
const ABILITIES_REL = "web/src/data/abilities.json";

/** The highest national dex number the apps have region and generation data for. */
const KNOWN_MAX_SPECIES = 1025;

/** The 18 types both apps hardcode a matchup chart for. */
const KNOWN_TYPES = new Set([
  "normal", "fire", "water", "electric", "grass", "ice", "fighting", "poison",
  "ground", "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark",
  "steel", "fairy",
]);

function baseRef() {
  const i = process.argv.indexOf("--base");
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : "HEAD";
}

function list(names, limit = 25) {
  if (names.length === 0) return "none";
  const shown = names.slice(0, limit).join(", ");
  return names.length > limit ? `${shown}, and ${names.length - limit} more` : shown;
}

async function committed(ref, rel) {
  const { stdout } = await execFileAsync("git", ["show", `${ref}:${rel}`], {
    cwd: ROOT,
    maxBuffer: 64 * 1024 * 1024,
  });
  return JSON.parse(stdout);
}

async function main() {
  const ref = baseRef();

  let previous;
  try {
    previous = await committed(ref, REL);
  } catch {
    process.stdout.write("No committed dataset to compare against — treating as a first import.\n");
    process.exit(1);
  }

  const current = JSON.parse(await readFile(path.join(ROOT, REL), "utf8"));

  // Ability descriptions are rendered in the detail-page popover, so a reworded
  // effect is a user-visible change even though no species record moved.
  let abilityChanges = [];
  try {
    const previousAbilities = await committed(ref, ABILITIES_REL);
    const currentAbilities = JSON.parse(await readFile(path.join(ROOT, ABILITIES_REL), "utf8"));
    abilityChanges = Object.keys(currentAbilities)
      .filter((name) => {
        const before = previousAbilities[name];
        const after = currentAbilities[name];
        return !before || before.description !== after.description;
      })
      .map((name) => currentAbilities[name].displayName ?? name);
  } catch {
    // Abilities file missing on one side is not fatal; the species diff still stands.
  }

  const before = new Map(previous.map((p) => [p.id, p]));
  const after = new Map(current.map((p) => [p.id, p]));

  const added = current.filter((p) => !before.has(p.id));
  const removed = previous.filter((p) => !after.has(p.id));

  const retyped = [];
  const megaChanged = [];
  const gmaxChanged = [];
  const formsChanged = [];

  for (const p of current) {
    const prev = before.get(p.id);
    if (!prev) continue;
    if (prev.types.join() !== p.types.join()) {
      retyped.push(`${p.displayName} (${prev.types.join("/")} → ${p.types.join("/")})`);
    }
    if (prev.hasMega !== p.hasMega) {
      megaChanged.push(`${p.displayName} (${p.hasMega ? "gained" : "lost"})`);
    }
    if (prev.hasGigantamax !== p.hasGigantamax) {
      gmaxChanged.push(`${p.displayName} (${p.hasGigantamax ? "gained" : "lost"})`);
    }
    if (prev.hasAlternateForms !== p.hasAlternateForms) {
      formsChanged.push(`${p.displayName} (${p.hasAlternateForms ? "gained" : "lost"})`);
    }
  }

  // Things a script cannot finish by itself.
  const beyondKnownRegions = current.filter((p) => p.id > KNOWN_MAX_SPECIES);
  const unknownTypes = [
    ...new Set(current.flatMap((p) => p.types).filter((t) => !KNOWN_TYPES.has(t))),
  ];

  const changed =
    added.length ||
    removed.length ||
    retyped.length ||
    megaChanged.length ||
    gmaxChanged.length ||
    formsChanged.length ||
    abilityChanges.length;

  const out = [];

  if (beyondKnownRegions.length || unknownTypes.length) {
    out.push("## ⚠️ Needs a human\n");
    if (beyondKnownRegions.length) {
      out.push(
        `**${beyondKnownRegions.length} species beyond #${KNOWN_MAX_SPECIES}** — this looks like a new generation.`,
        "",
        "Region and generation data is hand-written in both apps and cannot be derived:",
        "",
        "- `web/src/lib/regions.ts` — add the region (name, id range) and generation (numeral, colour)",
        "- `Pocket Dex/Features/Pokedex/Models/PokemonEnums.swift` — add the `PokemonRegion` case, its range, and the `PokemonGeneration` case",
        "",
        `New species: ${list(beyondKnownRegions.map((p) => `${p.displayName} #${p.id}`))}`,
        "",
      );
    }
    if (unknownTypes.length) {
      out.push(
        `**Unrecognised type(s): ${unknownTypes.join(", ")}** — the matchup chart is hand-written and is now incomplete.`,
        "",
        "- `web/src/lib/pokemon-type.ts`",
        "- `Pocket Dex/Features/TypeChart/Models/PokemonType.swift`",
        "",
        "`npm test` will fail until the chart covers every type.",
        "",
      );
    }
  }

  out.push("## What changed\n");

  if (!changed) {
    out.push(
      "No species or ability changes. Upstream moved, but nothing the apps render is different.",
      "",
    );
  } else {
    if (added.length) out.push(`- **Added (${added.length}):** ${list(added.map((p) => `${p.displayName} #${p.id}`))}`);
    if (removed.length) out.push(`- **Removed (${removed.length}):** ${list(removed.map((p) => p.displayName))}`);
    if (retyped.length) out.push(`- **Retyped (${retyped.length}):** ${list(retyped)}`);
    if (megaChanged.length) out.push(`- **Mega changed (${megaChanged.length}):** ${list(megaChanged)}`);
    if (gmaxChanged.length) out.push(`- **Gigantamax changed (${gmaxChanged.length}):** ${list(gmaxChanged)}`);
    if (formsChanged.length) out.push(`- **Alternate forms changed (${formsChanged.length}):** ${list(formsChanged)}`);
    if (abilityChanges.length) out.push(`- **Ability text changed (${abilityChanges.length}):** ${list(abilityChanges)}`);
    out.push("");
  }

  out.push("## Totals\n");
  out.push("| | before | after |");
  out.push("|---|---|---|");
  out.push(`| species | ${previous.length} | ${current.length} |`);
  out.push(`| with a Mega | ${previous.filter((p) => p.hasMega).length} | ${current.filter((p) => p.hasMega).length} |`);
  out.push(`| with a Gigantamax | ${previous.filter((p) => p.hasGigantamax).length} | ${current.filter((p) => p.hasGigantamax).length} |`);
  out.push(`| with alternate forms | ${previous.filter((p) => p.hasAlternateForms).length} | ${current.filter((p) => p.hasAlternateForms).length} |`);
  out.push("");

  process.stdout.write(out.join("\n"));
  process.exit(changed || beyondKnownRegions.length || unknownTypes.length ? 1 : 0);
}

main().catch((error) => {
  process.stderr.write(`${error.stack}\n`);
  process.exit(2);
});
