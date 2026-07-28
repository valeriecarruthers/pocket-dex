# Running the sync as a GitHub Action

An alternative to a Claude Routine: run the check in CI on a schedule and open the
pull request with the `gh` CLI. No Claude session involved, so it costs nothing on
quiet weeks, but the PR description is mechanical rather than written.

Save as `.github/workflows/pokedex-sync.yml`:

```yaml
name: Pokédex data sync

on:
  schedule:
    - cron: "0 14 * * 1" # Mondays, 14:00 UTC
  workflow_dispatch: # allow manual runs

permissions:
  contents: write
  pull-requests: write

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
          cache-dependency-path: web/package-lock.json

      - run: npm ci
        working-directory: web

      - id: check
        name: Has upstream moved?
        working-directory: web
        # --check exits 1 when the pinned commit is behind upstream.
        run: |
          if node scripts/build-dataset.mjs --check > check.json; then
            echo "drifted=false" >> "$GITHUB_OUTPUT"
          else
            echo "drifted=true" >> "$GITHUB_OUTPUT"
          fi
          cat check.json

      - name: Regenerate dataset
        if: steps.check.outputs.drifted == 'true'
        working-directory: web
        run: node scripts/build-dataset.mjs

      - name: Verify
        if: steps.check.outputs.drifted == 'true'
        working-directory: web
        run: |
          node --test --experimental-strip-types tests/type-chart.test.mjs
          npm run build

      - name: Open pull request
        if: steps.check.outputs.drifted == 'true'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          BRANCH="pokedex-sync/$(date +%Y-%m-%d)"
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git checkout -b "$BRANCH"
          git add web/src/data
          git commit -m "Refresh Pokédex dataset from upstream PokeAPI"
          git push -u origin "$BRANCH"
          gh pr create \
            --title "Refresh Pokédex dataset" \
            --body "Automated sync. Upstream \`PokeAPI/api-data\` moved; dataset regenerated and verified against \`npm run build\` and the type chart test."
```

## Notes

- The `--check` step is the whole point of the schedule: on a week where nothing
  moved, the job finishes in seconds and creates no branch or PR.
- `npm run build` prerenders all 1,025 species pages. It takes a couple of minutes,
  which is why it only runs when the data actually changed.
- If the type chart test fails, the job fails before opening a PR. That is
  deliberate — a matchup change needs a human to update
  `web/src/lib/pokemon-type.ts` by hand.
