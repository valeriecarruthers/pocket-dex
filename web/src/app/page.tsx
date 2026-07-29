import { Gallery } from "@/components/Gallery";
import { games, meta, pokedex } from "@/lib/dataset";

export default function HomePage() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Pokédex</h1>
        <p className="mt-1 text-sm text-muted">
          All {meta.counts.species.toLocaleString()} species and{" "}
          {meta.counts.varieties.toLocaleString()} forms, generated at build time so every
          page is static.
        </p>
      </div>

      <Gallery pokedex={pokedex} games={games} />
    </div>
  );
}
