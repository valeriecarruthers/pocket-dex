# Pocket Dex — web

Next.js 16 (App Router) + React 19 + Tailwind v4. Every page is prerendered at
build time from a dataset committed to the repository.

## Architecture

```
scripts/build-dataset.mjs   Generates the dataset from PokeAPI (build time only)
src/data/                   The generated dataset — committed
  pokedex.json                Gallery index (~143 KB, ships to the client)
  species/<id>.json           Per-species detail (read from disk at build time)
  abilities.json              Ability names + descriptions
  games.json                  Per-game species lists
  meta.json                   Pinned source commit, counts, generation timestamp
src/lib/                    Domain logic ported from Swift
  pokemon-type.ts             The 18 types and the full effectiveness chart
  regions.ts                  Regions, generations, game display names
  format.ts                   Display formatting and sprite URLs
  dataset.ts                  Server-side data access
src/components/             UI
tests/                      Verification of the hand-ported type chart
```

### Why the data is static

PokeAPI needs roughly three requests per Pokémon (species, variety, evolution
chain). Doing that at runtime makes for a slow, flaky app. Instead a build-time
script pulls everything once from the `PokeAPI/api-data` mirror — the same static
JSON that backs pokeapi.co — and commits the result.

The mirror is a git repository, so the dataset records the exact commit it came
from. That makes rebuilds reproducible and reduces "has upstream changed?" to a
single SHA comparison, which is what `npm run data:check` does and what the
`pokedex-sync` skill runs on a schedule.

### Why the type chart is hand-written

`src/lib/pokemon-type.ts` states the chart once from the attacker's point of view;
the defensive view (weak to / resists / immune to) is derived. This mirrors
`PokemonType.swift` and means the app needs no type data at runtime.

Hand-writing 324 matchups is only safe if something checks them, so `npm test`
verifies every one against PokeAPI's own `damage_relations`.

### Data flow

The gallery index is passed to a client component because search and filtering
happen in the browser — ~143 KB, about 25 KB gzipped. Per-species detail is read
from disk in a server component, so 1,025 detail files never enter a bundle; each
page pays only for its own data.

## Commands

| Command | What it does |
|---|---|
| `npm run dev` | Development server |
| `npm run build` | Prerenders all 1,049 pages |
| `npm test` | Verifies the type chart against upstream (`OFFLINE=1` to skip the network check) |
| `npm run data:check` | Exits non-zero if upstream data has moved |
| `npm run data:build` | Regenerates the dataset (~2 minutes) |
| `npm run screenshot` | Screenshots six pages × 2 viewports × 2 themes |

## Deploying to Vercel

1. Push the branch and import the repo at [vercel.com/new](https://vercel.com/new).
2. Set **Root Directory** to `web` — this is the only setting that matters, since
   the repo root is an Xcode project. Framework preset, build command, and output
   directory are all detected correctly.
3. Deploy. No environment variables are required; the dataset is committed.

Every push builds a preview URL; the default branch gets the production URL.

Because the dataset is committed rather than fetched, builds are hermetic — the
only network access is npm install. A `pokedex-sync` pull request is what changes
the data, so data updates go through review like any other change.

## Notes

- Images are served unoptimised from the PokeAPI sprite repository. They are
  already compressed PNGs on a CDN, so routing ~1,300 of them through the image
  optimiser would add cost and latency for no visual gain.
- `.screenshots/` and `.sprite-cache/` are QA artifacts and are not committed.
