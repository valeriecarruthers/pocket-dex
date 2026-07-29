import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { DetailSection } from "@/components/DetailSection";
import { PokemonCard } from "@/components/PokemonCard";
import { TypeBadge } from "@/components/TypeBadge";
import { pokedex } from "@/lib/dataset";
import { displayNameOf } from "@/lib/format";
import {
  POKEMON_TYPES,
  immuneTo,
  isPokemonType,
  noEffectAgainst,
  notVeryEffectiveAgainst,
  resists,
  superEffectiveAgainst,
  typeColor,
  weakTo,
} from "@/lib/pokemon-type";
import type { PokemonTypeName } from "@/lib/pokemon-type";

export function generateStaticParams() {
  return POKEMON_TYPES.map((type) => ({ type }));
}

export async function generateMetadata(
  props: PageProps<"/types/[type]">,
): Promise<Metadata> {
  const { type } = await props.params;
  if (!isPokemonType(type)) return { title: "Not found" };

  return {
    title: `${displayNameOf(type)} Type`,
    description: `Offensive and defensive matchups for the ${displayNameOf(type)} type, plus every ${displayNameOf(type)}-type Pokémon.`,
  };
}

export default async function TypeDetailPage(props: PageProps<"/types/[type]">) {
  const { type } = await props.params;
  if (!isPokemonType(type)) notFound();

  const name = type as PokemonTypeName;
  const members = pokedex.filter((pokemon) => pokemon.types.includes(name));

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        <Link href="/types" className="text-xs text-muted transition hover:text-foreground">
          ← Type Chart
        </Link>
        <div className="flex items-center gap-3">
          <span
            aria-hidden="true"
            className="h-8 w-2 rounded-full"
            style={{ backgroundColor: typeColor(name) }}
          />
          <h1 className="text-2xl font-bold tracking-tight">{displayNameOf(name)} Type</h1>
        </div>
        <p className="text-sm text-muted">
          {members.length.toLocaleString()} species have this type.
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <DetailSection title="Attacking">
          <div className="flex flex-col gap-3">
            <MatchupRow label="Super effective against" types={superEffectiveAgainst(name)} multiplier="2×" />
            <MatchupRow label="Not very effective against" types={notVeryEffectiveAgainst(name)} multiplier="½×" />
            <MatchupRow label="No effect against" types={noEffectAgainst(name)} multiplier="0×" />
          </div>
        </DetailSection>

        <DetailSection title="Defending">
          <div className="flex flex-col gap-3">
            <MatchupRow label="Weak to" types={weakTo(name)} multiplier="2×" />
            <MatchupRow label="Resists" types={resists(name)} multiplier="½×" />
            <MatchupRow label="Immune to" types={immuneTo(name)} multiplier="0×" />
          </div>
        </DetailSection>
      </div>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">
          {displayNameOf(name)} Pokémon
        </h2>
        <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
          {members.map((pokemon, index) => (
            <li key={pokemon.id}>
              <PokemonCard pokemon={pokemon} shiny={false} priority={index < 10} />
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

function MatchupRow({
  label,
  types,
  multiplier,
}: {
  label: string;
  types: PokemonTypeName[];
  multiplier: string;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <span className="text-[11px] text-muted">
        {label} <span className="font-mono">({multiplier})</span>
      </span>
      {types.length === 0 ? (
        <span className="text-xs text-muted">None</span>
      ) : (
        <div className="flex flex-wrap gap-1.5">
          {types.map((other) => (
            <TypeBadge key={other} type={other} size="sm" href={`/types/${other}`} />
          ))}
        </div>
      )}
    </div>
  );
}
