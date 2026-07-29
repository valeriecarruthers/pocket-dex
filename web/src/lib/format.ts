/** Display formatting shared across the app. Port of the Swift computed properties. */

export { displayNameOf } from "./regions";

/** 6 -> "#0006" */
export function formattedPokedexNumber(id: number): string {
  return `#${String(id).padStart(4, "0")}`;
}

/** PokeAPI stores decimetres. */
export function heightText(height: number): string {
  return `${(height / 10).toFixed(1)} m`;
}

/** PokeAPI stores hectograms. */
export function weightText(weight: number): string {
  return `${(weight / 10).toFixed(1)} kg`;
}

export function baseExperienceText(baseExperience: number | null): string {
  return baseExperience == null ? "Unknown" : String(baseExperience);
}

const SPRITE_BASE =
  "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon";

/** High-quality official artwork used as the final gallery/detail image. */
export function artworkURL(id: number, shiny = false): string {
  return shiny
    ? `${SPRITE_BASE}/other/official-artwork/shiny/${id}.png`
    : `${SPRITE_BASE}/other/official-artwork/${id}.png`;
}

/** Tiny (~1 KB) pixel sprite used as an instant low-res preview. */
export function spriteURL(id: number, shiny = false): string {
  return shiny ? `${SPRITE_BASE}/shiny/${id}.png` : `${SPRITE_BASE}/${id}.png`;
}

const STAT_LABELS: Record<string, string> = {
  hp: "HP",
  attack: "Attack",
  defense: "Defense",
  "special-attack": "Sp. Atk",
  "special-defense": "Sp. Def",
  speed: "Speed",
};

export function statLabel(name: string): string {
  return STAT_LABELS[name] ?? name;
}

/** A stable, distinct colour for an ability name. Port of Color.forAbility. */
const ABILITY_PALETTE = [
  "#3B82F6",
  "#22C55E",
  "#F97316",
  "#A855F7",
  "#EC4899",
  "#14B8A6",
  "#6366F1",
  "#EF4444",
  "#10B981",
  "#06B6D4",
  "#A16207",
];

export function abilityColor(name: string): string {
  let hash = 0;
  for (const char of name) {
    hash = (hash * 31 + char.codePointAt(0)!) & 0x7fffffff;
  }
  return ABILITY_PALETTE[hash % ABILITY_PALETTE.length];
}
