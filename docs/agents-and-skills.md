# Agents and skills, using this repo as the worked example

This repo now contains one of each of the main extension primitives. This document
explains what each one is, when to reach for it, and points at the working example
so you can read the real thing rather than a toy.

## The four primitives

| Primitive | Lives in | What it is | Example here |
|---|---|---|---|
| **Skill** | `.claude/skills/<name>/SKILL.md` | Procedural knowledge loaded on demand | `port-ios-feature`, `visual-qa` |
| **Scheduled skill** | A skill + a Routine or cron | A skill that fires on a timer instead of a request | `pokedex-sync` |
| **Subagent** | `.claude/agents/<name>.md` | A separate context with its own tools and job | `parity-check` |
| **Settings/permissions** | `.claude/settings.json` | Which tool calls run without asking | already present |

The distinction that matters most: **a skill is instructions, a subagent is a
worker.** A skill changes how the main assistant does something. A subagent goes
away, does a bounded job in its own context window, and comes back with a result.

## Skills

A skill is a Markdown file with YAML frontmatter. The frontmatter is always in
context; the body is loaded only when the skill triggers. That two-level loading
is the whole design — you can write a 300-line skill without paying 300 lines of
context on every unrelated turn.

```markdown
---
name: pokedex-sync
description: Checks whether upstream PokeAPI data has changed and… Use this skill
  whenever the user asks to check for new Pokémon, refresh the Pokédex data…
---

# Body: the actual instructions
```

### The description is the whole ballgame

The `description` is the *only* thing the model sees when deciding whether to
load your skill. Two rules follow from that:

1. **Say what it does AND when to use it.** All the triggering information goes
   in the description, not the body — by the time the body loads, the decision is
   already made.
2. **Be pushy.** The common failure is under-triggering: a perfectly good skill
   that never fires because the description was too modest. Compare:

   > ❌ "Checks for Pokédex data updates."
   >
   > ✅ "Checks whether upstream PokeAPI data has changed and, if it has,
   > regenerates the dataset and opens a PR. Use this skill whenever the user asks
   > to check for new Pokémon, refresh or update the Pokédex data, mentions a new
   > game being released, asks whether the dataset is stale, or wants to set up a
   > recurring data check."

   The second lists the phrasings a real person would actually use.

### Writing the body

Things that made these skills better, learned the hard way:

- **Explain why, not just what.** "Pin to a commit so staleness is one SHA
  comparison, not a thousand-endpoint diff" gets followed correctly in situations
  you did not anticipate. "Always pin to a commit" does not.
- **Go easy on the ALL-CAPS MUSTs.** If you are writing NEVER in caps, you
  probably have not explained the reason yet. A model that understands the
  constraint generalises it; one that has memorised a rule applies it literally
  and wrongly at the edges.
- **Give exact commands.** `npm run data:check` beats "check whether the data is
  current."
- **State the no-op case explicitly.** `pokedex-sync` says: if nothing changed,
  say so and stop — do not commit, do not open a PR. Without that, a scheduled
  job eventually opens an empty PR and you stop trusting it.
- **Push bulk into `references/`.** `pokedex-sync` keeps its GitHub Action YAML
  in `references/github-action.md`, loaded only when that path is taken.

### Anatomy

```
.claude/skills/pokedex-sync/
├── SKILL.md                        # frontmatter + instructions
└── references/
    └── github-action.md            # loaded only when needed
```

`scripts/` (executable helpers) and `assets/` (templates, images) are the other
two conventional subdirectories.

## Scheduled skills

`pokedex-sync` is the one you asked for: check for updates on a timer. It is an
ordinary skill; the schedule comes from outside.

Two ways to fire it:

**A Claude Routine** — a cron that opens a Claude session with a prompt:

> Cron `0 14 * * 1` (Mondays 14:00 UTC), prompt "Run the pokedex-sync skill."

Best when the job needs judgement — writing a real PR description, deciding
whether a change is safe.

**A GitHub Action** — see `.claude/skills/pokedex-sync/references/github-action.md`.
Best when the job is mechanical and you would rather not spend a session on it.

The design property that makes either safe to schedule: **the check is cheap and
the no-op is silent.** `npm run data:check` is one `git ls-remote` and one string
comparison. On a quiet week it exits in under a second having written nothing.
Build your scheduled skills so the boring path costs nothing, or you will turn
them off.

## Subagents

A subagent is a separate context window with its own system prompt, its own tool
allowlist, and one job. Frontmatter fields:

```markdown
---
name: parity-check
description: Compares the SwiftUI iOS app against the Next.js web app…
tools: Glob, Grep, Read, Bash      # omit for all tools
model: inherit                      # or sonnet / opus / haiku
---
```

### When a subagent beats a skill

Reach for a subagent when the job involves **reading a lot to produce a little**.
`parity-check` might read forty files across two codebases to produce a
twenty-line report. Done in the main conversation, those forty files sit in
context for the rest of the session. Done in a subagent, only the report comes
back.

The other reason is **independence**. A reviewer that has not watched you write
the code reviews it more honestly.

### The design rule worth internalising

Give a subagent one job and deny it the tools to do anything else. `parity-check`
has no `Edit` or `Write` — it *cannot* start fixing things. That is not
belt-and-braces; an agent that can edit will drift into editing, and then it stops
auditing halfway through and reports a partial picture. Constraining the tools is
how you constrain the behaviour.

Also: tell it what the output should look like. `parity-check` specifies a report
template with `file:line` anchors. Without that, subagent reports come back in a
different shape every time and you cannot skim them.

## How these four fit together

The intended loop for this repo:

1. **`parity-check`** (subagent) tells you what the web app is still missing.
2. **`port-ios-feature`** (skill) keeps each port consistent with the iOS original.
3. **`visual-qa`** (skill) confirms the result actually renders, in both themes and
   both viewports, before you believe it.
4. **`pokedex-sync`** (scheduled skill) keeps the underlying data current without
   anyone remembering to check.

Each teaches a different thing: delegation, codified conventions, verification,
and automation.

## Where to go next

- **Measure whether a skill helps.** The `skill-creator` skill has an evaluation
  harness: it runs the same prompts with and without a skill, grades the outputs
  against assertions, and shows you a side-by-side. Worth doing once so you learn
  what "this skill is actually working" looks like as evidence rather than vibes.
  It also has a description optimiser that tunes triggering against a set of
  should-trigger / should-not-trigger prompts.
- **Hooks** run shell commands automatically on events (before a tool call, after
  a file edit) — the right tool for "every time X happens, do Y," which skills
  cannot guarantee because they depend on the model choosing to load them.
- **Project settings** at `.claude/settings.json` control which tool calls run
  without prompting. This repo already allows the Xcode build and simulator
  commands.
