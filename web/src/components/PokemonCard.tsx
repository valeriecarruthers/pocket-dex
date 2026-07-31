import Image from "next/image";
import Link from "next/link";

import { artworkURL, formattedPokedexNumber } from "@/lib/format";
import { typeColor } from "@/lib/pokemon-type";
import type { PokemonSummary } from "@/lib/types";

/** Gallery cell. Port of PokemonGalleryCell.swift, including the alternate-form badges. */
export function PokemonCard({
  pokemon,
  shiny,
  priority,
}: {
  pokemon: PokemonSummary;
  shiny: boolean;
  priority?: boolean;
}) {
  const [primary] = pokemon.types;

  return (
    <Link
      href={`/pokemon/${pokemon.name}`}
      className="group relative flex flex-col items-center gap-2 rounded-2xl border border-border bg-surface p-3 transition hover:-translate-y-0.5 hover:border-transparent hover:shadow-lg focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      style={{ boxShadow: undefined }}
    >
      {/* Soft type-coloured wash behind the artwork. */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 rounded-2xl opacity-0 transition group-hover:opacity-10"
        style={{ backgroundColor: typeColor(primary ?? "normal") }}
      />

      <div className="relative aspect-square w-full">
        <Image
          src={shiny ? artworkURL(pokemon.id, true) : artworkURL(pokemon.id)}
          alt={pokemon.displayName}
          fill
          sizes="(max-width: 640px) 45vw, (max-width: 1024px) 22vw, 160px"
          loading={priority ? "eager" : "lazy"}
          priority={priority}
          className="object-contain drop-shadow-sm"
        />
      </div>

      <div className="relative flex w-full flex-col items-center gap-1.5">
        <span className="font-mono text-[11px] tabular-nums text-muted">
          {formattedPokedexNumber(pokemon.id)}
        </span>
        <span className="text-center text-sm font-semibold leading-tight">
          {pokemon.displayName}
        </span>
        <span className="flex flex-wrap justify-center gap-1">
          {pokemon.types.map((type) => (
            <span
              key={type}
              className="rounded-full px-2 py-0.5 text-[9px] font-semibold uppercase tracking-wide text-white"
              style={{ backgroundColor: typeColor(type) }}
            >
              {type}
            </span>
          ))}
        </span>
      </div>

      {(pokemon.hasMega || pokemon.hasGigantamax) && (
        <span className="absolute right-2 top-2 flex gap-1">
          {pokemon.hasMega && <FormBadge label="M" title="Has a Mega Evolution" />}
          {pokemon.hasGigantamax && <FormBadge label="G" title="Has a Gigantamax form" />}
        </span>
      )}
    </Link>
  );
}

function FormBadge({ label, title }: { label: string; title: string }) {
  return (
    <span
      title={title}
      className="grid h-4 w-4 place-items-center rounded-full bg-foreground/75 text-[9px] font-bold text-background"
    >
      {label}
    </span>
  );
}
