---
name: port-ios-feature
description: Ports a feature from the SwiftUI iOS app to the Next.js web app in web/, keeping naming, behaviour, and domain logic aligned across the two codebases. Use this skill whenever the user asks to add something to the web app that already exists on iOS, mentions bringing a screen/view/feature "to the web", asks to match the iOS app's behaviour, or names a specific SwiftUI view (PokedexView, PokemonDetailView, TypeChartView, SettingsView) in the context of web work. Also use it when adding a web feature that has an obvious iOS counterpart, so the port stays consistent instead of drifting.
---

# Porting an iOS feature to the web app

This repository holds one product built twice: a SwiftUI app at the repo root and
a Next.js app in `web/`. The value of that arrangement comes entirely from the two
staying recognisably the same product. A port that quietly renames things or
re-derives behaviour is worse than no port, because it costs the reader the
ability to trust either version.

Read the Swift original first, in full, before writing any TypeScript.

## Where things live

| iOS | Web |
|---|---|
| `Pocket Dex/Features/<Feature>/` | `web/src/app/` (routes), `web/src/components/` |
| `Pocket Dex/Features/*/Models/` | `web/src/lib/` |
| `Pocket Dex/Shared/Components/` | `web/src/components/` |
| `Pocket Dex/Shared/Extensions/` | `web/src/lib/format.ts` |
| `Pocket Dex/PokeAPI/` | `web/scripts/build-dataset.mjs` (build time only) |

The last row is the one that trips people up. iOS fetches from PokeAPI at runtime
and caches; the web app has no runtime API layer at all. Anything the web version
needs must already be in the generated dataset. If it is not, the change belongs
in `build-dataset.mjs` and the dataset must be regenerated — not papered over
with a client-side `fetch`.

## The porting rules that matter

**Keep the names.** A Swift `PokemonFormDetail` becomes a TypeScript
`PokemonFormDetail`. `formattedPokedexNumber` stays `formattedPokedexNumber`.
Someone reading both files should not have to translate vocabulary.

**Port derivations, don't re-derive them.** When Swift computes something with a
specific rule — `formLabel` stripping the species prefix, `PokeAPIEvolutionDetail.summary`
picking the first non-nil condition in a specific order — reproduce that order
exactly. These rules encode decisions, and quietly "improving" one makes the two
apps disagree on real Pokémon.

**Single source of truth survives the port.** `PokemonType.swift` expresses the
type chart once from the attacker's side and derives the defensive view from it.
`web/src/lib/pokemon-type.ts` does the same. If you find yourself writing a second
hardcoded table, stop — derive it.

**Server by default, client only for interaction.** A React component becomes a
client component (`"use client"`) only when it owns state or handlers. Static
presentation stays a server component so it costs nothing on the wire. Swift has
no equivalent distinction, so this is a judgement call you have to make fresh.

**Adapt platform idioms rather than emulating them.** A SwiftUI popover becomes a
positioned div that closes on outside-click and Escape. A `.searchable` modifier
becomes a controlled input. A fast-scroll index bar — which depends on native
scroll behaviour — becomes region filter chips. Emulating the mechanism produces
something that feels wrong on the web; porting the *intent* produces something
that feels right. Say which one you chose and why.

## What to do

1. Read the Swift view and every type it references.
2. Check whether the data it needs exists in `web/src/data/`. If not, extend
   `web/scripts/build-dataset.mjs` and regenerate before going further.
3. Write the domain logic into `web/src/lib/` first, with the Swift names.
4. Build the components, keeping the iOS component boundaries where they still
   make sense.
5. Verify — see below. A green typecheck is not verification.

## Verifying the port

```bash
cd web
npm run build
npm test
```

Then look at it. The `visual-qa` skill captures the pages in both themes and both
viewports and fails on console errors; use it rather than assuming a successful
build means a correct page.

If the port involved a derivation you could check against the Swift original —
form flags, type matchups, evolution requirements — check it directly instead of
trusting the read. A twelve-line script comparing your output against the
hardcoded Swift values catches the mistakes that review misses. The Mega and
Gigantamax sets in `PokemonModels.swift` were validated exactly this way.

## Deliberate divergences so far

These are intentional. Do not "fix" them without asking.

- **Base stats** appear on the web detail page but not on iOS. They come free in
  the same payload and a web Pokédex looks unfinished without them.
- **The fast-scroll index bar** is region filter chips on the web, because the
  gallery renders incrementally and there is no native section index to hook.
- **Settings** is an About page. The iOS cache-management controls have no web
  equivalent — there is no runtime cache to manage.
