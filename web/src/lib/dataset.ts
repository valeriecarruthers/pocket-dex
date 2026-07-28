/**
 * Server-side dataset access.
 *
 * The gallery index, abilities, and games are small enough to import directly.
 * Per-species detail is read from disk on demand so that 1,025 detail files are
 * never pulled into a client bundle — only the page being rendered pays for its
 * own data.
 */

import "server-only";

import { readFile } from "node:fs/promises";
import path from "node:path";

import abilitiesData from "@/data/abilities.json";
import gamesData from "@/data/games.json";
import metaData from "@/data/meta.json";
import pokedexData from "@/data/pokedex.json";

import type {
  AbilityInfo,
  DatasetMeta,
  Game,
  PokemonDetail,
  PokemonSummary,
} from "./types";

const SPECIES_DIR = path.join(process.cwd(), "src", "data", "species");

export const pokedex = pokedexData as PokemonSummary[];
export const abilities = abilitiesData as Record<string, AbilityInfo>;
export const games = gamesData as Game[];
export const meta = metaData as DatasetMeta;

const detailCache = new Map<number, PokemonDetail>();

export async function getSpecies(id: number): Promise<PokemonDetail | null> {
  const cached = detailCache.get(id);
  if (cached) return cached;

  try {
    const raw = await readFile(path.join(SPECIES_DIR, `${id}.json`), "utf8");
    const detail = JSON.parse(raw) as PokemonDetail;
    detailCache.set(id, detail);
    return detail;
  } catch {
    return null;
  }
}

export function getSummary(id: number): PokemonSummary | undefined {
  return pokedex.find((p) => p.id === id);
}

export function getSummaryByName(name: string): PokemonSummary | undefined {
  return pokedex.find((p) => p.name === name);
}

/** Neighbours in national dex order, for prev/next navigation. */
export function neighbours(id: number) {
  const index = pokedex.findIndex((p) => p.id === id);
  if (index === -1) return { previous: null, next: null };
  return {
    previous: index > 0 ? pokedex[index - 1] : null,
    next: index < pokedex.length - 1 ? pokedex[index + 1] : null,
  };
}

export function getAbility(name: string): AbilityInfo | undefined {
  return abilities[name];
}
