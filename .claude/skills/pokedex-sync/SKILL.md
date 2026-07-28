---
name: pokedex-sync
description: Checks whether upstream PokeAPI data has changed and, if it has, regenerates the web app's static dataset and opens a pull request describing exactly what moved. Use this skill whenever the user asks to check for new Pokémon, refresh or update the Pokédex data, mentions a new game or generation being released, asks whether the dataset is stale or out of date, or wants to set up a recurring/scheduled data check. Also use it when a scheduled job or Routine fires asking to sync Pokédex data.
---

# Pokédex dataset sync

The web app in `web/` renders from a static dataset committed to the repository,
generated from the `PokeAPI/api-data` mirror and pinned to an exact commit. That
pinning is what makes this job cheap: deciding "is our data stale?" is one SHA
comparison, not a diff of a thousand endpoints.

Your job is to answer that question and, when the answer is yes, produce a pull
request a human can review in under a minute.

## The short version

```bash
cd web
npm run data:check    # exit 0 = current, exit 1 = drifted
```

If it exits 0, say so and stop. Do not regenerate, do not open a PR, do not
commit. A no-op run should leave no trace — that is what makes it safe to run on
a schedule.

If it exits 1, work through the sections below.

## When the dataset has drifted

### 1. Regenerate

```bash
cd web
npm run data:build
```

This takes a couple of minutes and rewrites `web/src/data/`. It is deterministic
for a given upstream commit, so re-running it never produces spurious churn.

### 2. Work out what actually changed

`git diff --stat` on the dataset is close to useless — the files are minified
JSON on one line. What a reviewer wants is the semantic delta, so compute it:

```bash
cd web
git stash && node -e "
  const before = require('./src/data/meta.json');
  console.log(JSON.stringify(before.counts));
" ; git stash pop
```

More practically, compare the `counts` block in `web/src/data/meta.json` against
the committed version, and diff the species index by name:

```bash
cd web
git show HEAD:web/src/data/pokedex.json > /tmp/pokedex-old.json 2>/dev/null \
  || git show HEAD:src/data/pokedex.json > /tmp/pokedex-old.json
node -e "
  const oldList = require('/tmp/pokedex-old.json');
  const newList = require('./src/data/pokedex.json');
  const oldById = new Map(oldList.map(p => [p.id, p]));
  const newById = new Map(newList.map(p => [p.id, p]));

  const added = newList.filter(p => !oldById.has(p.id));
  const removed = oldList.filter(p => !newById.has(p.id));
  const retyped = newList.filter(p => {
    const prev = oldById.get(p.id);
    return prev && prev.types.join() !== p.types.join();
  });
  const formsChanged = newList.filter(p => {
    const prev = oldById.get(p.id);
    return prev && (prev.hasMega !== p.hasMega || prev.hasGigantamax !== p.hasGigantamax);
  });

  console.log('added:', added.map(p => p.displayName).join(', ') || 'none');
  console.log('removed:', removed.map(p => p.displayName).join(', ') || 'none');
  console.log('retyped:', retyped.map(p => p.displayName).join(', ') || 'none');
  console.log('form flags changed:', formsChanged.map(p => p.displayName).join(', ') || 'none');
"
```

Nothing semantic changing is a real and common outcome — upstream commits often
touch unrelated resources. Say so plainly in the PR rather than inventing
significance.

### 3. Verify before proposing

A dataset change can break the build (a new species with an unexpected shape, a
missing evolution chain). Check before asking anyone to review:

```bash
cd web
npm test
npm run build
```

The type chart test matters here beyond the obvious: if a generation introduced a
19th type or changed a matchup, the hand-written chart in
`src/lib/pokemon-type.ts` is now wrong and must be updated by hand. The test is
the tripwire for exactly that.

### 4. Open the pull request

Branch from the current default branch, commit only `web/src/data/`, and push.
Structure the description so the interesting part is first:

```markdown
## What changed
<the semantic delta — added/removed/retyped species, or "no semantic change">

## Source
`PokeAPI/api-data` moved from `<old-sha-12>` to `<new-sha-12>`.

## Counts
| | before | after |
|---|---|---|
| species | … | … |
| forms | … | … |

## Verification
- `npm run build` — <result>
- type chart test — <result>
```

If the type chart test failed, do not paper over it. Say what broke, leave the
dataset change out of the PR, and describe what a human needs to decide.

## Running this on a schedule

Weekly is the right cadence — PokeAPI moves slowly, and a daily job would mostly
produce empty runs. Two ways to wire it up, depending on where you want it to run:

**A Claude Routine** (runs in a Claude Code session, can open the PR itself):
ask for a Routine with a cron of `0 14 * * 1` (Mondays, 14:00 UTC) and a prompt
of "Run the pokedex-sync skill." Because the skill exits early when nothing has
changed, quiet weeks cost almost nothing.

**A GitHub Action** (runs in CI, no Claude session needed): see
`references/github-action.md` for a workflow that runs the check and opens the PR
with the `gh` CLI.

## Why it is built this way

The temptation with a "check for updates" job is to have it diff live API list
endpoints on every run. That is slow, rate-limited, and noisy — list ordering
changes produce phantom diffs. Pinning to a commit turns the question into a
string comparison, makes every rebuild byte-reproducible, and gives the PR a
precise, linkable statement of what the data came from.
