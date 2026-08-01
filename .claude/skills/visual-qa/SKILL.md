---
name: visual-qa
description: Builds and runs the web app, drives it in a real browser, and captures screenshots across both themes and viewports so you can actually look at a change before calling it done. Use this skill whenever the user asks to check how something looks, wants a screenshot or preview of the web app, asks whether a UI change worked, mentions dark mode or mobile layout, or after making any visual change to web/. Also use it before opening a pull request that touches the UI, since a passing build says nothing about whether the page renders correctly.
---

# Visual QA for the web app

A successful `next build` means the types line up and the pages prerendered. It
says nothing about whether the layout collapsed, the dark theme is unreadable, or
a client component threw after hydration. Those failures are invisible to the
build and obvious in a screenshot, which is the entire reason this skill exists.

Look at the screenshots. Capturing them and not opening them is the failure mode
this is meant to prevent.

## Running it

```bash
cd web
npm run build
npx next start -p 3210 &          # or: npm run dev
npm run screenshot
```

Output lands in `web/.screenshots/`:

- `<page>-<viewport>-<theme>.png` — six pages across desktop and mobile, light
  and dark, so 24 images
- `zoom/<element>-<theme>.png` — four single components at 2× device scale

Both sets matter, and they catch different things:

| | Catches |
|---|---|
| Page shots (1×) | Layout — overflow, collapsed columns, overlap, clipping |
| Close-ups (2×) | Rendering — wrong pixels inside an element that looks fine small |

**Look at the close-ups.** A sprite bleeding through transparent artwork once
survived a full 24-shot sweep unnoticed: at page scale the ghost read as part of
the illustration, and it was unmistakable the moment one card was magnified. If
you only skim the page shots, you are checking that boxes are in the right
places, not that their contents are correct.

The script exits non-zero on console errors, uncaught page errors, non-OK
responses, or failed same-origin requests. Treat a non-zero exit as a real
failure and read the list it prints; those are bugs the build could not see.

### If the browser will not launch

Sandboxes often ship a Chromium that does not match the npm package's pinned
revision. Point at the preinstalled binary instead of downloading a second copy:

```bash
CHROMIUM_PATH=/opt/pw-browsers/chromium node scripts/screenshot.mjs
```

Do not run `playwright install` to work around this.

## Reading the results

Open the images. Specifically check:

- **Dark theme** — text contrast, and surfaces that vanish into the background.
  Light-mode-only styling is the most common regression here.
- **Mobile** — the 390px viewport. Watch for horizontal overflow, the bottom tab
  bar overlapping content, and filter rows that clip rather than scroll.
- **Artwork** — sprites present rather than blank boxes.
- **Interactive state** — the gallery renders its first page server-side, so if
  cards are missing entirely the client component failed, not the data.

## Adding to the sweep

Two arrays in `web/scripts/screenshot.mjs`:

**`PAGES`** — whole pages, for layout. Keep it short and representative; it
exists to catch layout regressions, not to enumerate the site. Currently: the
gallery, a detail page with alternate forms (Charizard), one with a branching
evolution tree (Eevee), the type chart, a type detail page, and About.

**`ELEMENTS`** — single components magnified, for rendering. Keep these
image-heavy and compact, since that is where compositing bugs hide. Currently: a
gallery card, the detail hero artwork, one evolution-tree stage, and the matchup
grid.

Two things to get right when writing a selector:

- **Make sure it matches the element you mean.** `a[href='/pokemon/vaporeon']`
  looks specific but also matches the prev/next navigation link on Eevee's page,
  so the capture silently became a 32px-tall text link. `:has(img)` disambiguated
  it. Check the output dimensions after adding one — a surprising size means you
  captured the wrong node.
- **A selector that stops matching fails the run.** That is deliberate: markup
  moves, and a close-up that quietly disappears is worse than a loud failure.

## Failures the script ignores on purpose

Requests to `/_vercel/` are filtered out. The analytics script only exists on
Vercel's edge, so it 404s on every page of a local run — reporting it would make
the check fail every time and teach you to ignore the output. If you add another
platform-only path, extend `isPlatformOnly` rather than loosening the filter.

## Why sprites are served from Node

The script intercepts `raw.githubusercontent.com` and fulfils those requests with
bytes fetched in Node and cached in `web/.sprite-cache/`. This keeps runs
deterministic, avoids ~120 CDN round trips per screenshot, and lets the script
work in environments where the browser has no direct network egress. If you add
images from a new host, extend the route handler rather than letting the browser
fetch them — otherwise runs get slow and flaky for reasons that look like app
bugs.

## What this skill does not do

It captures and checks for errors; it does not diff against a baseline. If you
want true visual regression testing, the natural next step is committing approved
screenshots and comparing new captures against them — but be aware that sprite
artwork and font rendering vary enough between machines to make naive pixel
diffing noisy.
