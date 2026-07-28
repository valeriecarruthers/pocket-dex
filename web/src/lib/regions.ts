/**
 * Regions, generations, and game display names.
 * Port of PokemonEnums.swift and PokemonGame.displayName.
 */

export const REGIONS = [
  { id: "kanto", name: "Kanto", start: 1, end: 151 },
  { id: "johto", name: "Johto", start: 152, end: 251 },
  { id: "hoenn", name: "Hoenn", start: 252, end: 386 },
  { id: "sinnoh", name: "Sinnoh", start: 387, end: 493 },
  { id: "unova", name: "Unova", start: 494, end: 649 },
  { id: "kalos", name: "Kalos", start: 650, end: 721 },
  { id: "alola", name: "Alola", start: 722, end: 809 },
  { id: "galar", name: "Galar", start: 810, end: 905 },
  { id: "paldea", name: "Paldea", start: 906, end: 1025 },
] as const;

export type RegionId = (typeof REGIONS)[number]["id"];

export function regionFor(pokedexNumber: number) {
  return REGIONS.find((r) => pokedexNumber >= r.start && pokedexNumber <= r.end) ?? null;
}

export function regionName(pokedexNumber: number): string {
  return regionFor(pokedexNumber)?.name ?? "Unknown";
}

/** Short label for the fast-scroll index ("Kan", "Joh", …). */
export function regionShortName(region: { name: string }): string {
  return region.name.slice(0, 3);
}

export const GENERATIONS = [
  { number: 1, numeral: "I", region: "Kanto", color: "#E3350D" },
  { number: 2, numeral: "II", region: "Johto", color: "#C9A227" },
  { number: 3, numeral: "III", region: "Hoenn", color: "#00A651" },
  { number: 4, numeral: "IV", region: "Sinnoh", color: "#2E86DE" },
  { number: 5, numeral: "V", region: "Unova", color: "#5D5D5D" },
  { number: 6, numeral: "VI", region: "Kalos", color: "#E0559A" },
  { number: 7, numeral: "VII", region: "Alola", color: "#F0803C" },
  { number: 8, numeral: "VIII", region: "Galar", color: "#7A5CC8" },
  { number: 9, numeral: "IX", region: "Paldea", color: "#0E9594" },
] as const;

export function generationFor(pokedexNumber: number) {
  const region = regionFor(pokedexNumber);
  return GENERATIONS.find((g) => g.region === region?.name) ?? null;
}

/**
 * Groups games by the generation whose region they belong to, so remakes and
 * region-linked side games (Legends) sit with the original generation rather
 * than their release year.
 */
export function generationForVersionGroup(name: string): number | null {
  switch (name) {
    case "red-blue":
    case "yellow":
    case "firered-leafgreen":
    case "lets-go-pikachu-lets-go-eevee":
    case "red-green-japan":
    case "blue-japan":
      return 1;
    case "gold-silver":
    case "crystal":
    case "heartgold-soulsilver":
      return 2;
    case "ruby-sapphire":
    case "emerald":
    case "omega-ruby-alpha-sapphire":
    case "colosseum":
    case "xd":
      return 3;
    case "diamond-pearl":
    case "platinum":
    case "brilliant-diamond-shining-pearl":
    case "legends-arceus":
      return 4;
    case "black-white":
    case "black-2-white-2":
      return 5;
    case "x-y":
    case "legends-za":
    case "mega-dimension":
      return 6;
    case "sun-moon":
    case "ultra-sun-ultra-moon":
      return 7;
    case "sword-shield":
    case "the-isle-of-armor":
    case "the-crown-tundra":
      return 8;
    case "scarlet-violet":
    case "the-teal-mask":
    case "the-indigo-disk":
      return 9;
    default:
      return null;
  }
}

const GAME_NAMES: Record<string, string> = {
  "red-blue": "Red & Blue",
  "gold-silver": "Gold & Silver",
  "ruby-sapphire": "Ruby & Sapphire",
  "firered-leafgreen": "FireRed & LeafGreen",
  "diamond-pearl": "Diamond & Pearl",
  "heartgold-soulsilver": "HeartGold & SoulSilver",
  "black-white": "Black & White",
  "black-2-white-2": "Black 2 & White 2",
  "x-y": "X & Y",
  "omega-ruby-alpha-sapphire": "Omega Ruby & Alpha Sapphire",
  "sun-moon": "Sun & Moon",
  "ultra-sun-ultra-moon": "Ultra Sun & Ultra Moon",
  "lets-go-pikachu-lets-go-eevee": "Let's Go Pikachu & Eevee",
  "sword-shield": "Sword & Shield",
  "brilliant-diamond-shining-pearl": "Brilliant Diamond & Shining Pearl",
  "legends-arceus": "Legends: Arceus",
  "scarlet-violet": "Scarlet & Violet",
  "legends-za": "Legends: Z-A",
  "the-isle-of-armor": "The Isle of Armor",
  "the-crown-tundra": "The Crown Tundra",
  "the-teal-mask": "The Teal Mask",
  "the-indigo-disk": "The Indigo Disk",
  "red-green-japan": "Red & Green",
  "blue-japan": "Blue (JP)",
  "mega-dimension": "Mega Dimension",
};

export function gameDisplayName(name: string): string {
  return GAME_NAMES[name] ?? displayNameOf(name);
}

/** "zapdos-galar" -> "Zapdos Galar". Port of String.displayName. */
export function displayNameOf(raw: string): string {
  return raw
    .split("-")
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}
