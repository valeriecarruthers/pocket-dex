/**
 * sync-ios-sets.mjs
 *
 * Rewrites the hardcoded species sets in the iOS app from the generated web
 * dataset, so a data update lands on both platforms instead of only one.
 *
 * `PokemonModels.swift` hardcodes three sets — which species have a Mega, a
 * Gigantamax, and more than one variety — because the iOS app cannot afford to
 * derive them at runtime. The web dataset already contains the same facts, and
 * the derivation was verified to reproduce all three sets exactly (87 / 32 /
 * 224), so regenerating them mechanically is safe and removes the drift risk.
 *
 * Usage:
 *   node scripts/sync-ios-sets.mjs            # rewrite in place
 *   node scripts/sync-ios-sets.mjs --check    # exit 1 if out of date, write nothing
 */

import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DATASET = path.join(ROOT, "web", "src", "data", "pokedex.json");
const SWIFT = path.join(ROOT, "Pocket Dex", "Features", "Pokedex", "Models", "PokemonModels.swift");

const CHECK_ONLY = process.argv.includes("--check");

/**
 * Matches the existing hand-written style exactly: 8-space indent, wrapped so
 * that a line including its trailing comma is at most 93 characters.
 *
 * The width is not cosmetic. If it differed from the committed file, every sync
 * run would produce a diff even when no species changed, and the scheduled job
 * would open pull requests that say nothing.
 */
const MAX_LINE = 93;

function formatSwiftSet(ids) {
  const lines = [];
  let line = "";

  for (const id of ids) {
    const token = line ? `${line}, ${id}` : String(id);
    if (`        ${token},`.length > MAX_LINE) {
      lines.push(`        ${line},`);
      line = String(id);
    } else {
      line = token;
    }
  }
  if (line) lines.push(`        ${line}`);

  return lines.join("\n");
}

/** Replaces the body of `private static let <name>: Set<Int> = [ … ]`. */
function replaceSet(source, name, ids) {
  const pattern = new RegExp(
    `(private static let ${name}: Set<Int> = \\[\\n)([\\s\\S]*?)(\\n    \\])`,
  );
  if (!pattern.test(source)) {
    throw new Error(`Could not locate ${name} in PokemonModels.swift`);
  }
  return source.replace(pattern, `$1${formatSwiftSet(ids)}$3`);
}

async function main() {
  const pokedex = JSON.parse(await readFile(DATASET, "utf8"));
  const original = await readFile(SWIFT, "utf8");

  const sets = {
    megaSpecies: pokedex.filter((p) => p.hasMega).map((p) => p.id),
    gigantamaxSpecies: pokedex.filter((p) => p.hasGigantamax).map((p) => p.id),
    speciesWithForms: pokedex.filter((p) => p.hasAlternateForms).map((p) => p.id),
  };

  let updated = original;
  for (const [name, ids] of Object.entries(sets)) {
    updated = replaceSet(updated, name, [...ids].sort((a, b) => a - b));
  }

  const counts = Object.fromEntries(
    Object.entries(sets).map(([name, ids]) => [name, ids.length]),
  );

  if (updated === original) {
    process.stdout.write(`iOS sets already current ${JSON.stringify(counts)}\n`);
    return;
  }

  if (CHECK_ONLY) {
    process.stderr.write(
      `iOS sets are out of date. Run: node scripts/sync-ios-sets.mjs\n` +
        `Expected ${JSON.stringify(counts)}\n`,
    );
    process.exit(1);
  }

  await writeFile(SWIFT, updated);
  process.stdout.write(`Rewrote iOS sets ${JSON.stringify(counts)}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack}\n`);
  process.exit(1);
});
