#!/usr/bin/env bash
#
# Decides what happens to a data-sync pull request.
#
# Most weeks a sync carries no user-visible change — upstream corrected a typo
# or touched an unrelated resource, and the only real edit is the pinned commit
# in meta.json. Reviewing those by hand is busywork that trains you to rubber
# stamp, which is exactly when a real change slips through. So:
#
#   nothing user-visible  ->  merge itself once CI passes, no notification
#   something changed     ->  assign the owner and wait for a human
#
# Auto-merge still waits for every required check, so the type chart is
# verified against upstream and the site is built before anything merges.
#
# Usage: triage-sync-pr.sh <branch> <changed:0|1> <owner>

set -euo pipefail

BRANCH="$1"
CHANGED="$2"
OWNER="$3"

if [ "$CHANGED" = "1" ]; then
  echo "Species or ability data changed — assigning $OWNER for review."
  gh pr edit "$BRANCH" --add-assignee "$OWNER"

  # If a previous quiet run armed auto-merge on this same long-lived branch,
  # disarm it: this content now needs a person.
  gh pr merge "$BRANCH" --disable-auto 2>/dev/null || true
  exit 0
fi

echo "No user-visible changes — arming auto-merge."

# Nobody is assigned, so this produces no notification.
gh pr edit "$BRANCH" --remove-assignee "$OWNER" 2>/dev/null || true

if ! gh pr merge "$BRANCH" --auto --squash --delete-branch 2> /tmp/merge-error.log; then
  cat /tmp/merge-error.log

  if grep -qi "auto.merge is not allowed\|Auto-merge is not enabled" /tmp/merge-error.log; then
    echo "::warning::Auto-merge is not enabled for this repository."
    {
      echo "## Auto-merge could not be armed"
      echo
      echo "The pull request is open and correct — it just will not merge itself."
      echo
      echo "**Enable it once:** Settings → General → Pull Requests →"
      echo "tick **Allow auto-merge** → Save."
    } >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
  fi

  # A pull request that needs a manual merge is not a failure worth failing the
  # run over — but it does need someone to notice, so assign it.
  gh pr edit "$BRANCH" --add-assignee "$OWNER" || true
fi
