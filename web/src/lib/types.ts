/** Shapes emitted by scripts/build-dataset.mjs. */

export interface PokemonSummary {
  id: number;
  name: string;
  displayName: string;
  types: string[];
  hasAlternateForms: boolean;
  hasMega: boolean;
  hasGigantamax: boolean;
}

export interface PokemonAbility {
  name: string;
  isHidden: boolean;
}

export interface PokemonStat {
  name: string;
  value: number;
}

/** The form-specific data that changes when switching forms. */
export interface PokemonFormDetail {
  regularImageURL: string | null;
  shinyImageURL: string | null;
  types: string[];
  abilities: PokemonAbility[];
  height: number;
  weight: number;
  baseExperience: number | null;
  stats: PokemonStat[];
}

/** A single form/variety (e.g. Galarian Zapdos, Mega Charizard X). */
export interface PokemonForm {
  name: string;
  label: string;
  isDefault: boolean;
  detail: PokemonFormDetail | null;
}

export interface EvolutionNode {
  id: number;
  name: string;
  requirement: string | null;
  children: EvolutionNode[];
}

export interface PokemonDetail {
  id: number;
  name: string;
  displayName: string;
  flavorText: string | null;
  genus: string | null;
  habitat: string | null;
  evolutionTree: EvolutionNode[];
  forms: PokemonForm[];
  defaultForm: PokemonFormDetail;
}

export interface AbilityInfo {
  displayName: string;
  description: string | null;
}

export interface Game {
  id: number;
  name: string;
  speciesIds: number[];
}

export interface DatasetMeta {
  sourceRepo: string;
  sourceRef: string;
  generatedAt: string;
  counts: {
    species: number;
    varieties: number;
    evolutionChains: number;
    abilities: number;
    games: number;
  };
}
