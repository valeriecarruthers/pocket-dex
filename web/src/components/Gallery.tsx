"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import { FilterChip } from "@/components/FilterChip";
import { PokemonCard } from "@/components/PokemonCard";
import { formattedPokedexNumber } from "@/lib/format";
import { POKEMON_TYPES, typeColor } from "@/lib/pokemon-type";
import { REGIONS, gameDisplayName, generationForVersionGroup } from "@/lib/regions";
import type { Game, PokemonSummary } from "@/lib/types";

type FormFilter = "all" | "mega" | "gigantamax";
type SortOption = "pokedexNumber" | "name";

/** Cards added each time the sentinel scrolls into view. */
const PAGE_SIZE = 120;

export function Gallery({
  pokedex,
  games,
}: {
  pokedex: PokemonSummary[];
  games: Game[];
}) {
  const [query, setQuery] = useState("");
  const [region, setRegion] = useState<string>("all");
  const [type, setType] = useState<string>("all");
  const [formFilter, setFormFilter] = useState<FormFilter>("all");
  const [gameId, setGameId] = useState<number | "all">("all");
  const [sort, setSort] = useState<SortOption>("pokedexNumber");
  const [shiny, setShiny] = useState(false);
  const [visible, setVisible] = useState(PAGE_SIZE);

  const gameSpecies = useMemo(() => {
    if (gameId === "all") return null;
    const game = games.find((g) => g.id === gameId);
    return game ? new Set(game.speciesIds) : null;
  }, [gameId, games]);

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();
    const activeRegion = REGIONS.find((r) => r.id === region);

    const result = pokedex.filter((pokemon) => {
      if (gameSpecies && !gameSpecies.has(pokemon.id)) return false;
      if (activeRegion && (pokemon.id < activeRegion.start || pokemon.id > activeRegion.end)) {
        return false;
      }
      if (type !== "all" && !pokemon.types.includes(type)) return false;
      if (formFilter === "mega" && !pokemon.hasMega) return false;
      if (formFilter === "gigantamax" && !pokemon.hasGigantamax) return false;

      if (needle) {
        const matchesName = pokemon.displayName.toLowerCase().includes(needle);
        // Searching "25" or "0025" should both find Pikachu.
        const matchesNumber =
          String(pokemon.id).includes(needle) ||
          formattedPokedexNumber(pokemon.id).includes(needle);
        if (!matchesName && !matchesNumber) return false;
      }

      return true;
    });

    return sort === "name"
      ? [...result].sort((a, b) => a.displayName.localeCompare(b.displayName))
      : result;
  }, [pokedex, query, region, type, formFilter, gameSpecies, sort]);

  // Reset paging whenever the filters change, so narrowing the results never
  // leaves the user scrolled past the end of a now-shorter list. Adjusting state
  // during render (rather than in an effect) avoids rendering one frame with the
  // stale page size.
  const filterKey = `${query}|${region}|${type}|${formFilter}|${gameId}|${sort}`;
  const [lastFilterKey, setLastFilterKey] = useState(filterKey);
  if (lastFilterKey !== filterKey) {
    setLastFilterKey(filterKey);
    setVisible(PAGE_SIZE);
  }

  const sentinel = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const node = sentinel.current;
    if (!node) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) {
          setVisible((current) => Math.min(current + PAGE_SIZE, filtered.length));
        }
      },
      { rootMargin: "600px" },
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, [filtered.length]);

  const shown = filtered.slice(0, visible);

  const sortedGames = useMemo(
    () => [...games].sort((a, b) => a.id - b.id),
    [games],
  );

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-col gap-3">
        <div className="flex items-center gap-2">
          <div className="relative flex-1">
            <svg
              viewBox="0 0 24 24"
              aria-hidden="true"
              className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted"
              fill="currentColor"
            >
              <path d="M10 2a8 8 0 1 0 4.9 14.32l4.4 4.39a1 1 0 0 0 1.4-1.42l-4.38-4.38A8 8 0 0 0 10 2Zm0 2a6 6 0 1 1 0 12 6 6 0 0 1 0-12Z" />
            </svg>
            <input
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search by name or number"
              aria-label="Search Pokémon"
              className="w-full rounded-xl border border-border bg-surface py-2.5 pl-9 pr-3 text-sm outline-none transition placeholder:text-muted focus:border-accent"
            />
          </div>

          <button
            type="button"
            onClick={() => setShiny((value) => !value)}
            aria-pressed={shiny}
            title={shiny ? "Showing shiny artwork" : "Show shiny artwork"}
            className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border transition ${
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

        <FilterRow label="Region">
          <FilterChip label="All Regions" selected={region === "all"} onClick={() => setRegion("all")} />
          {REGIONS.map((r) => (
            <FilterChip
              key={r.id}
              label={r.name}
              selected={region === r.id}
              onClick={() => setRegion(region === r.id ? "all" : r.id)}
            />
          ))}
        </FilterRow>

        <FilterRow label="Type">
          <FilterChip label="All Types" selected={type === "all"} onClick={() => setType("all")} />
          {POKEMON_TYPES.map((t) => (
            <FilterChip
              key={t}
              label={t.charAt(0).toUpperCase() + t.slice(1)}
              selected={type === t}
              color={typeColor(t)}
              onClick={() => setType(type === t ? "all" : t)}
            />
          ))}
        </FilterRow>

        <div className="flex flex-wrap items-center gap-2">
          <FilterChip label="All Forms" selected={formFilter === "all"} onClick={() => setFormFilter("all")} />
          <FilterChip
            label="Mega Evolution"
            selected={formFilter === "mega"}
            onClick={() => setFormFilter(formFilter === "mega" ? "all" : "mega")}
          />
          <FilterChip
            label="Gigantamax"
            selected={formFilter === "gigantamax"}
            onClick={() => setFormFilter(formFilter === "gigantamax" ? "all" : "gigantamax")}
          />

          <select
            value={gameId}
            onChange={(event) =>
              setGameId(event.target.value === "all" ? "all" : Number(event.target.value))
            }
            aria-label="Filter by game"
            className="rounded-full border border-border bg-surface px-3 py-1 text-xs text-muted outline-none transition focus:border-accent"
          >
            <option value="all">All Games</option>
            {sortedGames.map((game) => {
              const generation = generationForVersionGroup(game.name);
              return (
                <option key={game.id} value={game.id}>
                  {gameDisplayName(game.name)}
                  {generation ? ` (Gen ${generation})` : ""}
                </option>
              );
            })}
          </select>

          <select
            value={sort}
            onChange={(event) => setSort(event.target.value as SortOption)}
            aria-label="Sort order"
            className="rounded-full border border-border bg-surface px-3 py-1 text-xs text-muted outline-none transition focus:border-accent"
          >
            <option value="pokedexNumber">Pokédex Number</option>
            <option value="name">Name</option>
          </select>

          <span className="ml-auto text-xs text-muted">
            {filtered.length.toLocaleString()}{" "}
            {filtered.length === 1 ? "Pokémon" : "Pokémon"}
          </span>
        </div>
      </div>

      {filtered.length === 0 ? (
        <p className="rounded-2xl border border-border bg-surface px-4 py-12 text-center text-sm text-muted">
          No Pokémon match those filters.
        </p>
      ) : (
        <>
          <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
            {shown.map((pokemon, index) => (
              <li key={pokemon.id}>
                <PokemonCard pokemon={pokemon} shiny={shiny} priority={index < 10} />
              </li>
            ))}
          </ul>
          <div ref={sentinel} aria-hidden="true" className="h-px" />
        </>
      )}
    </div>
  );
}

function FilterRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center gap-2">
      <span className="w-12 shrink-0 text-[11px] font-medium uppercase tracking-wide text-muted">
        {label}
      </span>
      <div className="flex gap-1.5 overflow-x-auto pb-1 [scrollbar-width:thin]">{children}</div>
    </div>
  );
}
