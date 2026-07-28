/**
 * The 18 Pokemon types and the canonical (Gen 6+) type-effectiveness chart.
 *
 * Port of PokemonType.swift. As in the iOS app, the chart is expressed once from
 * the attacker's point of view — each type lists the defenders it hits for 2x,
 * 1/2x, and 0x. The defensive view (weak to / resists / immune to) is derived
 * from those three lists, so there is a single source of truth to keep correct.
 */

export const POKEMON_TYPES = [
  // Declared in canonical type-chart order so grids and pickers read naturally.
  "normal",
  "fire",
  "water",
  "electric",
  "grass",
  "ice",
  "fighting",
  "poison",
  "ground",
  "flying",
  "psychic",
  "bug",
  "rock",
  "ghost",
  "dragon",
  "dark",
  "steel",
  "fairy",
] as const;

export type PokemonTypeName = (typeof POKEMON_TYPES)[number];

/** Defenders each type deals 2x damage to when attacking. */
const SUPER_EFFECTIVE: Record<PokemonTypeName, PokemonTypeName[]> = {
  normal: [],
  fire: ["grass", "ice", "bug", "steel"],
  water: ["fire", "ground", "rock"],
  electric: ["water", "flying"],
  grass: ["water", "ground", "rock"],
  ice: ["grass", "ground", "flying", "dragon"],
  fighting: ["normal", "ice", "rock", "dark", "steel"],
  poison: ["grass", "fairy"],
  ground: ["fire", "electric", "poison", "rock", "steel"],
  flying: ["grass", "fighting", "bug"],
  psychic: ["fighting", "poison"],
  bug: ["grass", "psychic", "dark"],
  rock: ["fire", "ice", "flying", "bug"],
  ghost: ["psychic", "ghost"],
  dragon: ["dragon"],
  dark: ["psychic", "ghost"],
  steel: ["ice", "rock", "fairy"],
  fairy: ["fighting", "dragon", "dark"],
};

/** Defenders each type deals 1/2x damage to when attacking. */
const NOT_VERY_EFFECTIVE: Record<PokemonTypeName, PokemonTypeName[]> = {
  normal: ["rock", "steel"],
  fire: ["fire", "water", "rock", "dragon"],
  water: ["water", "grass", "dragon"],
  electric: ["electric", "grass", "dragon"],
  grass: ["fire", "grass", "poison", "flying", "bug", "dragon", "steel"],
  ice: ["fire", "water", "ice", "steel"],
  fighting: ["poison", "flying", "psychic", "bug", "fairy"],
  poison: ["poison", "ground", "rock", "ghost"],
  ground: ["grass", "bug"],
  flying: ["electric", "rock", "steel"],
  psychic: ["psychic", "steel"],
  bug: ["fire", "fighting", "poison", "flying", "ghost", "steel", "fairy"],
  rock: ["fighting", "ground", "steel"],
  ghost: ["dark"],
  dragon: ["steel"],
  dark: ["fighting", "dark", "fairy"],
  steel: ["fire", "water", "electric", "steel"],
  fairy: ["fire", "poison", "steel"],
};

/** Defenders each type deals no damage to. */
const NO_EFFECT: Record<PokemonTypeName, PokemonTypeName[]> = {
  normal: ["ghost"],
  fire: [],
  water: [],
  electric: ["ground"],
  grass: [],
  ice: [],
  fighting: ["ghost"],
  poison: ["steel"],
  ground: ["flying"],
  flying: [],
  psychic: ["dark"],
  bug: [],
  rock: [],
  ghost: ["normal"],
  dragon: ["fairy"],
  dark: [],
  steel: [],
  fairy: [],
};

/** Damage multiplier `attacker` deals to `defender` (0, 0.5, 1, or 2). */
export function attackMultiplier(
  attacker: PokemonTypeName,
  defender: PokemonTypeName,
): number {
  if (NO_EFFECT[attacker].includes(defender)) return 0;
  if (SUPER_EFFECTIVE[attacker].includes(defender)) return 2;
  if (NOT_VERY_EFFECTIVE[attacker].includes(defender)) return 0.5;
  return 1;
}

export function superEffectiveAgainst(type: PokemonTypeName): PokemonTypeName[] {
  return SUPER_EFFECTIVE[type];
}

export function notVeryEffectiveAgainst(type: PokemonTypeName): PokemonTypeName[] {
  return NOT_VERY_EFFECTIVE[type];
}

export function noEffectAgainst(type: PokemonTypeName): PokemonTypeName[] {
  return NO_EFFECT[type];
}

/** Types that hit `type` for 2x when it is defending. */
export function weakTo(type: PokemonTypeName): PokemonTypeName[] {
  return POKEMON_TYPES.filter((attacker) => attackMultiplier(attacker, type) === 2);
}

/** Types `type` takes 1/2x from when defending. */
export function resists(type: PokemonTypeName): PokemonTypeName[] {
  return POKEMON_TYPES.filter((attacker) => attackMultiplier(attacker, type) === 0.5);
}

/** Types `type` takes no damage from when defending. */
export function immuneTo(type: PokemonTypeName): PokemonTypeName[] {
  return POKEMON_TYPES.filter((attacker) => attackMultiplier(attacker, type) === 0);
}

/** Compact label for a multiplier cell ("0", "½", "1", "2"). */
export function effectivenessLabel(multiplier: number): string {
  switch (multiplier) {
    case 0:
      return "0";
    case 0.5:
      return "½";
    case 2:
      return "2";
    default:
      return "1";
  }
}

/**
 * Combined defensive multiplier for a Pokemon whose typing is `defenderTypes`
 * (dual types stack multiplicatively, e.g. 2x * 2x = 4x).
 */
export function defensiveMultiplier(
  attacker: PokemonTypeName,
  defenderTypes: PokemonTypeName[],
): number {
  return defenderTypes.reduce(
    (total, defender) => total * attackMultiplier(attacker, defender),
    1,
  );
}

/** A distinct three-letter label for dense grid headers ("Fir", "Fig", "Fly", …). */
export function typeAbbreviation(type: PokemonTypeName): string {
  return type.slice(0, 3).charAt(0).toUpperCase() + type.slice(1, 3);
}

/** Canonical colour for each type, matching Color+Pokemon.swift. */
export const TYPE_COLORS: Record<PokemonTypeName, string> = {
  normal: "#A8A77A",
  fire: "#EE8130",
  water: "#6390F0",
  electric: "#F7D02C",
  grass: "#7AC74C",
  ice: "#96D9D6",
  fighting: "#C22E28",
  poison: "#A33EA1",
  ground: "#E2BF65",
  flying: "#A98FF3",
  psychic: "#F95587",
  bug: "#A6B91A",
  rock: "#B6A136",
  ghost: "#735797",
  dragon: "#6F35FC",
  dark: "#705746",
  steel: "#B7B7CE",
  fairy: "#D685AD",
};

export function typeColor(type: string): string {
  return TYPE_COLORS[type.toLowerCase() as PokemonTypeName] ?? "#9CA3AF";
}

export function isPokemonType(value: string): value is PokemonTypeName {
  return (POKEMON_TYPES as readonly string[]).includes(value.toLowerCase());
}
