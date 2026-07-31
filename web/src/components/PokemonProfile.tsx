"use client";

import Image from "next/image";
import { useState } from "react";

import { AbilityChip } from "@/components/AbilityChip";
import { DetailSection, StatCard } from "@/components/DetailSection";
import { EvolutionTree } from "@/components/EvolutionTree";
import { TypeBadge } from "@/components/TypeBadge";
import {
  artworkURL,
  baseExperienceText,
  heightText,
  statLabel,
  weightText,
} from "@/lib/format";
import {
  POKEMON_TYPES,
  defensiveMultiplier,
  effectivenessLabel,
  isPokemonType,
  typeColor,
} from "@/lib/pokemon-type";
import { regionName } from "@/lib/regions";
import type { AbilityInfo, PokemonDetail } from "@/lib/types";

/**
 * The interactive half of a detail page. Switching forms swaps artwork, typing,
 * abilities, measurements, and stats together — mirroring PokemonDetailView.swift.
 */
export function PokemonProfile({
  detail,
  abilities,
}: {
  detail: PokemonDetail;
  abilities: Record<string, AbilityInfo>;
}) {
  const forms = detail.forms.filter((form) => form.detail !== null);
  const defaultIndex = Math.max(
    0,
    forms.findIndex((form) => form.isDefault),
  );

  const [formIndex, setFormIndex] = useState(defaultIndex);
  const [shiny, setShiny] = useState(false);

  const form = forms[formIndex] ?? forms[0];
  const formDetail = form?.detail ?? detail.defaultForm;

  // Alternate forms have their own artwork URLs; the default form falls back to
  // the species artwork so it matches the gallery image exactly.
  const image = form?.isDefault
    ? shiny
      ? artworkURL(detail.id, true)
      : artworkURL(detail.id)
    : (shiny ? formDetail.shinyImageURL : formDetail.regularImageURL) ??
      artworkURL(detail.id, shiny);

  // 18 multiplications — cheap enough to just compute, and memoizing it here
  // fights the React Compiler for no measurable gain.
  const defenderTypes = formDetail.types.filter(isPokemonType);
  const defenses =
    defenderTypes.length === 0
      ? []
      : POKEMON_TYPES.map((attacker) => ({
          attacker,
          multiplier: defensiveMultiplier(attacker, defenderTypes),
        })).filter((entry) => entry.multiplier !== 1);

  const maxStat = Math.max(...formDetail.stats.map((stat) => stat.value), 1);

  return (
    <div className="flex flex-col gap-4">
      <div className="grid gap-4 md:grid-cols-[minmax(0,320px)_minmax(0,1fr)]">
        {/* Artwork + form switcher */}
        <div className="flex flex-col gap-3 rounded-2xl border border-border bg-surface p-4">
          <div className="relative aspect-square w-full">
            <Image
              src={image}
              alt={`${detail.displayName}${form && !form.isDefault ? ` (${form.label})` : ""}`}
              fill
              sizes="(max-width: 768px) 90vw, 320px"
              priority
              className="object-contain"
            />

            <button
              type="button"
              onClick={() => setShiny((value) => !value)}
              aria-pressed={shiny}
              title={shiny ? "Showing shiny artwork" : "Show shiny artwork"}
              className={`absolute right-0 top-0 flex h-9 w-9 items-center justify-center rounded-full border transition ${
                shiny
                  ? "border-transparent bg-amber-400 text-amber-950"
                  : "border-border bg-surface text-muted hover:text-foreground"
              }`}
            >
              <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden="true">
                <path d="M12 2.5l2.2 5.6 5.8.35-4.5 3.7 1.5 5.65L12 14.7l-5 3.1 1.5-5.65-4.5-3.7 5.8-.35L12 2.5Z" />
              </svg>
            </button>
          </div>

          <div className="flex flex-wrap justify-center gap-1.5">
            {formDetail.types.map((type) => (
              <TypeBadge key={type} type={type} href={`/types/${type}`} />
            ))}
          </div>

          {forms.length > 1 && (
            <div className="flex flex-wrap justify-center gap-1.5 border-t border-border pt-3">
              {forms.map((candidate, index) => (
                <button
                  key={candidate.name}
                  type="button"
                  onClick={() => setFormIndex(index)}
                  aria-pressed={index === formIndex}
                  className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                    index === formIndex
                      ? "border-accent bg-surface-muted text-foreground"
                      : "border-border text-muted hover:text-foreground"
                  }`}
                >
                  {candidate.label}
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="flex flex-col gap-4">
          {detail.flavorText && (
            <DetailSection title="Pokédex Entry">
              <p className="text-sm leading-relaxed">{detail.flavorText}</p>
            </DetailSection>
          )}

          <DetailSection title="Profile">
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
              <StatCard title="Region" value={regionName(detail.id)} />
              <StatCard title="Height" value={heightText(formDetail.height)} />
              <StatCard title="Weight" value={weightText(formDetail.weight)} />
              <StatCard title="Base XP" value={baseExperienceText(formDetail.baseExperience)} />
              <StatCard title="Habitat" value={detail.habitat ?? "Unknown"} />
              <StatCard title="Genus" value={detail.genus ?? "Unknown"} />
            </div>
          </DetailSection>

          <DetailSection title="Abilities">
            <div className="flex flex-wrap gap-2">
              {formDetail.abilities.map((ability) => (
                <AbilityChip
                  key={`${ability.name}-${ability.isHidden}`}
                  name={ability.name}
                  isHidden={ability.isHidden}
                  info={abilities[ability.name]}
                />
              ))}
            </div>
          </DetailSection>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <DetailSection title="Base Stats">
          <ul className="flex flex-col gap-2">
            {formDetail.stats.map((stat) => (
              <li key={stat.name} className="flex items-center gap-3">
                <span className="w-16 shrink-0 text-[11px] text-muted">
                  {statLabel(stat.name)}
                </span>
                <span className="w-8 shrink-0 text-right font-mono text-xs tabular-nums">
                  {stat.value}
                </span>
                <span className="h-2 flex-1 overflow-hidden rounded-full bg-surface-muted">
                  <span
                    className="block h-full rounded-full"
                    style={{
                      width: `${(stat.value / maxStat) * 100}%`,
                      backgroundColor: typeColor(formDetail.types[0] ?? "normal"),
                    }}
                  />
                </span>
              </li>
            ))}
          </ul>
        </DetailSection>

        <DetailSection title="Type Defenses">
          {defenses.length === 0 ? (
            <p className="text-sm text-muted">Takes normal damage from every type.</p>
          ) : (
            <ul className="flex flex-wrap gap-1.5">
              {defenses.map(({ attacker, multiplier }) => (
                <li
                  key={attacker}
                  className="flex items-center gap-1 rounded-full bg-surface-muted py-0.5 pl-0.5 pr-2"
                >
                  <span
                    className="rounded-full px-2 py-0.5 text-[9px] font-semibold uppercase tracking-wide text-white"
                    style={{ backgroundColor: typeColor(attacker) }}
                  >
                    {attacker}
                  </span>
                  <span
                    className={`font-mono text-[11px] font-semibold tabular-nums ${
                      multiplier > 1 ? "text-red-500" : "text-emerald-500"
                    }`}
                  >
                    {multiplier === 4
                      ? "4"
                      : multiplier === 0.25
                        ? "¼"
                        : effectivenessLabel(multiplier)}
                    ×
                  </span>
                </li>
              ))}
            </ul>
          )}
        </DetailSection>
      </div>

      <DetailSection title="Evolution">
        <div className="overflow-x-auto pb-1">
          <EvolutionTree nodes={detail.evolutionTree} currentId={detail.id} />
        </div>
      </DetailSection>
    </div>
  );
}
