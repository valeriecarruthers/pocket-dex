import type { Metadata } from "next";

import { TypeBadge } from "@/components/TypeBadge";
import { TypeChartGrid } from "@/components/TypeChartGrid";
import { POKEMON_TYPES } from "@/lib/pokemon-type";

export const metadata: Metadata = {
  title: "Type Chart",
  description:
    "The full Gen 6+ Pokémon type effectiveness chart — every attacking and defending matchup.",
};

export default function TypeChartPage() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Type Chart</h1>
        <p className="mt-1 text-sm text-muted">
          Rows attack, columns defend. Pick a type for its full offensive and defensive
          breakdown.
        </p>
      </div>

      <div className="flex flex-wrap gap-1.5">
        {POKEMON_TYPES.map((type) => (
          <TypeBadge key={type} type={type} href={`/types/${type}`} />
        ))}
      </div>

      <div className="rounded-2xl border border-border bg-surface p-4">
        <TypeChartGrid />

        <ul className="mt-4 flex flex-wrap gap-3 text-[11px] text-muted">
          <Legend className="bg-emerald-500/85" label="2× super effective" />
          <Legend className="bg-red-500/75" label="½× not very effective" />
          <Legend className="bg-foreground/70" label="0× no effect" />
          <Legend className="bg-surface-muted" label="1× normal" />
        </ul>
      </div>
    </div>
  );
}

function Legend({ className, label }: { className: string; label: string }) {
  return (
    <li className="flex items-center gap-1.5">
      <span aria-hidden="true" className={`h-3 w-5 rounded ${className}`} />
      {label}
    </li>
  );
}
