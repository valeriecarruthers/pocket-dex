# Pocket Dex

One product, built twice: a SwiftUI iOS app and a static Next.js web app that
share a data contract and their domain rules.

```
Pocket Dex/          SwiftUI iOS app
web/                 Next.js web app
.claude/skills/      Skills — pokedex-sync, port-ios-feature, visual-qa
.claude/agents/      Subagents — parity-check
docs/                Notes, including a guide to the agents and skills
```

## The web app

All 1,025 species and 1,351 forms, prerendered at build time — every Pokémon has
its own URL, there are no API calls at runtime, and nothing breaks if PokeAPI has
a bad day.

- **Gallery** — search by name or number, filter by region, type, Mega/Gigantamax,
  and game, sort by number or name, shiny toggle
- **Detail pages** — official artwork, Pokédex entry, profile, abilities with
  descriptions, base stats, computed type defenses, evolution tree, alternate-form
  switcher
- **Type chart** — the full 18×18 matchup grid plus a page per type

```bash
cd web
npm install
npm run dev          # http://localhost:3000
```

| Command | What it does |
|---|---|
| `npm run build` | Prerenders all 1,049 pages |
| `npm test` | Verifies the type chart against PokeAPI's damage relations |
| `npm run data:check` | Exits non-zero if upstream PokeAPI data has moved |
| `npm run data:build` | Regenerates the dataset (~2 minutes) |
| `npm run screenshot` | Captures the app in both themes and viewports |

See [`web/README.md`](web/README.md) for architecture and deployment.

## Skills and agents

The repo doubles as a worked example of Claude Code's extension primitives —
a scheduled skill, two procedural skills, and a subagent.
[`docs/agents-and-skills.md`](docs/agents-and-skills.md) walks through what each
one is and why it is built the way it is.

| | Type | Job |
|---|---|---|
| `pokedex-sync` | Scheduled skill | Detects upstream data changes, regenerates, opens a PR |
| `port-ios-feature` | Skill | Keeps SwiftUI → React ports consistent |
| `visual-qa` | Skill | Builds, drives a real browser, screenshots, fails on console errors |
| `parity-check` | Subagent | Audits where the two apps have diverged |

## Data and attribution

Data comes from [PokeAPI](https://pokeapi.co) via the `PokeAPI/api-data` mirror,
pinned to an exact commit so builds are reproducible. Pokémon and Pokémon
character names are trademarks of Nintendo. This is a non-commercial fan project.
