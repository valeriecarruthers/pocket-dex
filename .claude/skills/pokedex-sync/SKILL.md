---
name: pokedex-sync
description: Checks whether upstream PokeAPI data has changed and, if it has, regenerates the web dataset, rewrites the iOS app's hardcoded species sets to match, and opens a pull request describing exactly what moved. Use this skill whenever the user asks to check for new Pokémon, refresh or update the Pokédex data, mentions a new game or generation being released, asks whether the dataset is stale or out of date, wants to know why the two apps disagree about forms, or wants to set up or debug a recurring data check. Also use it when a scheduled job or Routine fires asking to sync Pokédex data.
---

# Pokédex data sync

Both apps render from the same upstream facts, but they store them differently:

- **Web** reads a generated dataset committed at `web/src/data/`, pinned to an
  exact `PokeAPI/api-data` commit.
- **iOS** hardcodes three species sets in `PokemonModels.swift` — which species
  have a Mega, a Gigantamax, and more than one variety — because it cannot
  afford to derive them at runtime.

A data update has to land on both, or they drift apart silently. That is the
whole job.

## This normally runs itself

`.github/workflows/pokedex-sync.yml` does all of the below on a weekly schedule
and is free on a public repository. **Check whether it already ran before doing
anything by hand** — a `pokedex-sync/*` branch or an open pull request means the
work is done and needs review, not repeating.

Run it on demand from the Actions tab (**Run workflow**), which is usually
better than driving it manually.

**If the run fails at "Open a pull request"** with *"GitHub Actions is not
permitted to create or approve pull requests"*, that is a one-time repository
setting, not a broken workflow: Settings → Actions → General → Workflow
permissions → tick **Allow GitHub Actions to create and approve pull requests**.
The branch is pushed before the pull request is attempted, so nothing is lost —
re-run, or open the pull request from the existing `pokedex-sync/*` branch by
hand.

Drive it by hand when the automation is broken, when you need to reason about a
change it flagged for a human, or when you are testing a change to the pipeline
itself.

## Doing it by hand

```bash
cd web
npm run data:check     # exit 0 = current, exit 1 = upstream moved
```

Exit 0 means stop. Do not regenerate, do not commit, do not open a pull request.
A no-op run should leave no trace — that is what makes this safe to schedule.

If it exits 1:

```bash
npm run data:build     # regenerate the web dataset (~2 minutes)
npm run data:report    # what actually changed, in species terms
npm run ios:sync       # rewrite the iOS sets from the new dataset
npm test               # 324 type matchups vs upstream
npm run build
```

Then commit `web/src/data/` and `Pocket Dex/Features/Pokedex/Models/PokemonModels.swift`
together and open a pull request with the report as the body.

## Reading the report

`data:report` exists because `git diff --stat` is useless here — the dataset is
minified JSON on one line, so it says "1 file changed" whether upstream fixed a
typo or shipped a generation. The report turns that into species-level facts:
added, removed, retyped, and changed form flags, with before/after totals.

It exits 0 when nothing user-visible changed, 1 when something did.

**Upstream moving without any user-visible change is normal and common.** Say so
plainly rather than inventing significance. The pull request is still worth
merging, because it advances the pinned commit — otherwise the next run
regenerates everything again from the same stale pin.

## The two things a script cannot finish

The report flags these loudly. Both need a person, and both affect **both**
codebases:

**A new generation** — species numbered above #1025. Region names, dex ranges,
generation numerals and colours are editorial, not derivable:

- `web/src/lib/regions.ts`
- `Pocket Dex/Features/Pokedex/Models/PokemonEnums.swift`

**A new or changed type** — the matchup chart is written out by hand in both
apps, once from the attacker's side with the defensive view derived:

- `web/src/lib/pokemon-type.ts`
- `Pocket Dex/Features/TypeChart/Models/PokemonType.swift`

`npm test` is the tripwire for the second one: it checks all 324 matchups against
upstream's own `damage_relations`, so a chart that has gone stale fails rather
than shipping quietly. If it fails, do not merge the data change — say what broke
and what a human needs to decide.

## Why the iOS sets are rewritten rather than reviewed

`scripts/sync-ios-sets.mjs` regenerates the three Swift arrays from the dataset.
This is safe because the derivation was verified to reproduce the hand-written
file **byte for byte** — same 87 Mega, 32 Gigantamax, 224 multi-form species, same
wrapping.

That byte-stability is load-bearing, not cosmetic. If the generated formatting
differed from the committed file, every run would produce a diff even when no
species changed, and the schedule would open pull requests that say nothing.
`npm run ios:sync -- --check` exits non-zero when the sets are stale, which is
how you tell the two apps have drifted.

The iOS project is not built by the workflow — that needs macOS. The rewrite is
mechanical and formatting-stable, so the diff should contain only species
numbers. If it contains anything else, something is wrong with the generator.

## Does parity-check belong here?

Usually no, and it is worth knowing why.

`parity-check` finds *feature* drift — something one app does that the other
does not. A data sync does not cause feature drift; it causes data drift, and
`ios:sync` already fixes that by construction.

The exception is a change the report flags for a human. Adding a generation
touches regions, generations, and possibly the type chart across both codebases,
and that is exactly when an independent audit earns its keep. Run it *after* the
manual edits, to confirm the two apps agree again.

## Cost

Free. Actions minutes are unlimited on public repositories, and a quiet week is
one `git ls-remote` plus a string comparison — it finishes in seconds without
installing dependencies, because `build-dataset.mjs` uses only Node built-ins.

A Claude Routine could do the same job and write a better prose summary, but it
spends session usage every week to usually say "nothing changed". For a
portfolio project the Action is the right trade.
