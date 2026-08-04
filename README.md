# Pocket Dex

**Live web app → [pocket-dex-vc.vercel.app](https://pocket-dex-vc.vercel.app)**

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

## How it maintains itself

Three GitHub Actions, all free on a public repository. The intent is that a
quiet month needs no attention at all, and anything that does need attention
finds you rather than waiting to be noticed.

| Workflow | Runs | Does |
|---|---|---|
| `ci` | Every pull request | Lint, type-chart test, build, and an iOS/web data drift check |
| `pokedex-sync` | Weekly | Detects upstream PokeAPI changes, regenerates the dataset, rewrites the iOS species sets |
| `uptime` | Every 6 hours, and after each deploy | Checks the live site serves a working Pokédex |

**Routine syncs merge themselves.** When a sync carries no user-visible change —
usually just a new pinned upstream commit — it arms auto-merge and notifies
nobody. CI still has to pass first. Reviewing those by hand is busywork that
trains you to rubber stamp, which is when a real change slips through.

**Real changes wait for a person.** New species, retyped Pokémon, changed
Mega/Gigantamax flags, or reworded ability text assign the pull request to the
repository owner, which is what generates the notification. A new generation or
an unrecognised type is flagged even louder, because region and type data is
hand-written in both apps and cannot be derived.

**A broken site opens an issue.** The health check asserts on page content, not
just status codes, so a build that deploys successfully but renders an empty
gallery still fails. It comments on the existing issue rather than opening a new
one every six hours, and closes it on recovery.

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

## Disclaimer

Pocket Dex is a **personal portfolio project**, built to demonstrate software
development skills. It is non-commercial, generates no revenue, and is not
intended for commercial distribution or general public use.

This project is not affiliated with, endorsed by, or sponsored by Nintendo, Game
Freak, Creatures Inc., or The Pokémon Company. Pokémon and all related names,
characters, artwork, and sprites are trademarks and copyrights of their
respective owners, used here for non-commercial, illustrative purposes only.

Data comes from [PokeAPI](https://pokeapi.co) — a free and open API — via the
`PokeAPI/api-data` mirror, pinned to an exact commit so builds are reproducible.
Sprite artwork is served from the [PokeAPI sprite
repository](https://github.com/PokeAPI/sprites). If you own rights to material
shown here and would like it removed, please open an issue.
