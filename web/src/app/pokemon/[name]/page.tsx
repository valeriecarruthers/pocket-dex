import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { PokemonProfile } from "@/components/PokemonProfile";
import { abilities as allAbilities, getSpecies, getSummaryByName, neighbours, pokedex } from "@/lib/dataset";
import { formattedPokedexNumber } from "@/lib/format";
import { generationFor, regionName } from "@/lib/regions";
import type { AbilityInfo } from "@/lib/types";

/** Prerenders a page per species, so every Pokémon has its own shareable URL. */
export function generateStaticParams() {
  return pokedex.map((pokemon) => ({ name: pokemon.name }));
}

export async function generateMetadata(
  props: PageProps<"/pokemon/[name]">,
): Promise<Metadata> {
  const { name } = await props.params;
  const summary = getSummaryByName(name);
  if (!summary) return { title: "Not found" };

  const detail = await getSpecies(summary.id);
  const description =
    detail?.flavorText ??
    `${summary.displayName} — ${summary.types.join(" / ")} type Pokémon, ${formattedPokedexNumber(summary.id)}.`;

  return {
    title: summary.displayName,
    description,
    openGraph: {
      title: `${summary.displayName} · Pocket Dex`,
      description,
      images: [
        `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${summary.id}.png`,
      ],
    },
  };
}

export default async function PokemonPage(props: PageProps<"/pokemon/[name]">) {
  const { name } = await props.params;
  const summary = getSummaryByName(name);
  if (!summary) notFound();

  const detail = await getSpecies(summary.id);
  if (!detail) notFound();

  // Ship only the ability descriptions this page actually renders, rather than
  // the full 373-entry map.
  const abilityNames = new Set(
    detail.forms.flatMap((form) => form.detail?.abilities.map((a) => a.name) ?? []),
  );
  const abilities: Record<string, AbilityInfo> = {};
  for (const abilityName of abilityNames) {
    const info = allAbilities[abilityName];
    if (info) abilities[abilityName] = info;
  }

  const { previous, next } = neighbours(summary.id);
  const generation = generationFor(summary.id);

  return (
    <div className="flex flex-col gap-5">
      <nav className="flex items-center justify-between gap-3 text-xs">
        {previous ? (
          <Link href={`/pokemon/${previous.name}`} className="text-muted transition hover:text-foreground">
            ← {previous.displayName}
          </Link>
        ) : (
          <span />
        )}
        <Link href="/" className="text-muted transition hover:text-foreground">
          All Pokémon
        </Link>
        {next ? (
          <Link href={`/pokemon/${next.name}`} className="text-muted transition hover:text-foreground">
            {next.displayName} →
          </Link>
        ) : (
          <span />
        )}
      </nav>

      <header className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <h1 className="text-3xl font-bold tracking-tight">{detail.displayName}</h1>
        <span className="font-mono text-lg tabular-nums text-muted">
          {formattedPokedexNumber(detail.id)}
        </span>
        <span className="text-sm text-muted">
          {detail.genus ?? "Unknown"} · {regionName(detail.id)}
          {generation ? ` · Gen ${generation.numeral}` : ""}
        </span>
      </header>

      <PokemonProfile detail={detail} abilities={abilities} />
    </div>
  );
}
