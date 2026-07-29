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

Output lands in `web/.screenshots/` as `<page>-<viewport>-<theme>.png` — six
pages across desktop and mobile, light and dark, so 24 images.

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

## Adding a page to the sweep

Edit the `PAGES` array in `web/scripts/screenshot.mjs`. Keep the list short and
representative — it exists to catch layout regressions, not to enumerate the
site. The current set covers the gallery, a detail page with alternate forms
(Charizard), a detail page with a branching evolution tree (Eevee), the type
chart, a type detail page, and About.

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
