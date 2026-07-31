/**
 * screenshot.mjs — drives the running app in a real browser and captures pages.
 *
 * Used by the `visual-qa` skill so an agent can look at what it built rather
 * than assume a green build means a correct page. It also fails on console
 * errors and failed same-origin requests, which a build log will not surface.
 *
 * Sprite images are fetched in Node and fulfilled into the page rather than
 * being loaded by the browser directly. That keeps runs deterministic, avoids
 * ~120 CDN round trips per screenshot, and means the script works in sandboxes
 * where the browser has no direct egress.
 *
 * Usage:
 *   node scripts/screenshot.mjs [--base http://localhost:3210] [--out .screenshots]
 *   CHROMIUM_PATH=/path/to/chrome node scripts/screenshot.mjs   # use a preinstalled browser
 */

import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

import { chromium } from "playwright";

function arg(flag, fallback) {
  const index = process.argv.indexOf(flag);
  return index !== -1 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
}

const BASE = arg("--base", "http://localhost:3210");
const OUT = path.resolve(arg("--out", ".screenshots"));
const SPRITE_CACHE = path.resolve(arg("--sprite-cache", ".sprite-cache"));

// Some sandboxes ship a Chromium build that does not match the npm package's
// pinned revision; point at the preinstalled binary instead of downloading one.
const EXECUTABLE_PATH = process.env.CHROMIUM_PATH || undefined;

const PAGES = [
  { name: "gallery", url: "/" },
  { name: "detail-charizard", url: "/pokemon/charizard" },
  { name: "detail-eevee", url: "/pokemon/eevee" },
  { name: "type-chart", url: "/types" },
  { name: "type-fire", url: "/types/fire" },
  { name: "about", url: "/about" },
];

const VIEWPORTS = [
  { name: "desktop", width: 1280, height: 900 },
  { name: "mobile", width: 390, height: 844 },
];

/**
 * Single elements captured magnified, at 2x device scale.
 *
 * A full-page screenshot at 1x proves the layout is right; it is too small to
 * prove the *pixels* are right. A sprite bleeding through transparent artwork
 * survived a full 24-shot sweep unnoticed and was obvious the moment one card
 * was magnified — so the sweep now always ends with a few close-ups of the
 * places where images and text actually get composited.
 *
 * Keep this list short and image-heavy. It exists to catch rendering bugs,
 * not to re-inventory the site.
 */
const ELEMENTS = [
  { name: "card", url: "/", selector: "a[href='/pokemon/charizard']" },
  { name: "detail-artwork", url: "/pokemon/charizard", selector: "img[alt='Charizard']" },
  // :has(img) distinguishes the evolution-tree card from the prev/next nav
  // link, which points at the same href on this page.
  { name: "evolution-stage", url: "/pokemon/eevee", selector: "a[href='/pokemon/vaporeon']:has(img)" },
  { name: "type-chart-grid", url: "/types", selector: "table" },
];

/** Transparent 1x1 PNG, used when a sprite genuinely cannot be fetched. */
const BLANK_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "base64",
);

/**
 * Paths served by the Vercel runtime, which does not exist locally. The
 * analytics script 404s on every page in a local run; reporting that would
 * make the check fail every time and train you to ignore its output.
 */
function isPlatformOnly(url) {
  return url.includes("/_vercel/");
}

const memoryCache = new Map();

async function spriteBytes(url) {
  if (memoryCache.has(url)) return memoryCache.get(url);

  const file = path.join(SPRITE_CACHE, encodeURIComponent(url).slice(-180));

  try {
    const cached = await readFile(file);
    memoryCache.set(url, cached);
    return cached;
  } catch {
    // Not cached yet — fall through and fetch it.
  }

  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const bytes = Buffer.from(await response.arrayBuffer());
    await writeFile(file, bytes);
    memoryCache.set(url, bytes);
    return bytes;
  } catch {
    memoryCache.set(url, BLANK_PNG);
    return BLANK_PNG;
  }
}

async function main() {
  await mkdir(OUT, { recursive: true });
  await mkdir(SPRITE_CACHE, { recursive: true });

  const browser = await chromium.launch({ executablePath: EXECUTABLE_PATH });
  const problems = [];

  for (const viewport of VIEWPORTS) {
    for (const theme of ["light", "dark"]) {
      const context = await browser.newContext({
        viewport: { width: viewport.width, height: viewport.height },
        colorScheme: theme,
        deviceScaleFactor: 1,
      });

      // Serve sprites from Node so the browser never needs external egress.
      await context.route("https://raw.githubusercontent.com/**", async (route) => {
        const body = await spriteBytes(route.request().url());
        await route.fulfill({ status: 200, contentType: "image/png", body });
      });

      for (const page of PAGES) {
        const label = `${page.url} [${viewport.name}/${theme}]`;
        const tab = await context.newPage();

        tab.on("console", (message) => {
          if (message.type() !== "error") return;
          // Resource errors carry the offending URL in the location, so they
          // can be filtered as precisely as the request events below.
          if (isPlatformOnly(message.location()?.url ?? "")) return;
          problems.push(`console error on ${label}: ${message.text()}`);
        });
        tab.on("pageerror", (error) => {
          problems.push(`page error on ${label}: ${error.message}`);
        });
        tab.on("requestfailed", (request) => {
          // Only same-origin failures indicate a bug in the app itself.
          if (!request.url().startsWith(BASE)) return;
          if (isPlatformOnly(request.url())) return;
          problems.push(`request failed on ${label}: ${request.url()}`);
        });

        const response = await tab.goto(`${BASE}${page.url}`, {
          waitUntil: "domcontentloaded",
          timeout: 30_000,
        });
        if (!response?.ok()) problems.push(`HTTP ${response?.status()} for ${label}`);

        // Let artwork decode and any client filtering settle before capturing.
        await tab.waitForLoadState("networkidle", { timeout: 15_000 }).catch(() => {});
        await tab.waitForTimeout(400);

        await tab.screenshot({
          path: path.join(OUT, `${page.name}-${viewport.name}-${theme}.png`),
        });

        await tab.close();
      }

      await context.close();
    }
  }

  // Close-ups. Same pages, but one element at a time and magnified, because a
  // full-page shot is too small to show whether the pixels are actually right.
  const zoomDir = path.join(OUT, "zoom");
  await mkdir(zoomDir, { recursive: true });

  for (const theme of ["light", "dark"]) {
    const context = await browser.newContext({
      viewport: { width: 1280, height: 900 },
      colorScheme: theme,
      deviceScaleFactor: 2,
    });

    await context.route("https://raw.githubusercontent.com/**", async (route) => {
      const body = await spriteBytes(route.request().url());
      await route.fulfill({ status: 200, contentType: "image/png", body });
    });

    for (const element of ELEMENTS) {
      const label = `${element.name} [${theme}]`;
      const tab = await context.newPage();

      await tab.goto(`${BASE}${element.url}`, {
        waitUntil: "domcontentloaded",
        timeout: 30_000,
      });
      await tab.waitForLoadState("networkidle", { timeout: 15_000 }).catch(() => {});
      await tab.waitForTimeout(400);

      const target = tab.locator(element.selector).first();
      if ((await target.count()) === 0) {
        // A selector that stops matching usually means the markup moved, which
        // is worth failing on — otherwise coverage silently disappears.
        problems.push(`no element matched ${element.selector} for ${label}`);
      } else {
        await target.screenshot({ path: path.join(zoomDir, `${element.name}-${theme}.png`) });
      }

      await tab.close();
    }

    await context.close();
  }

  await browser.close();

  if (problems.length > 0) {
    process.stderr.write(`\n${problems.length} problem(s):\n`);
    for (const problem of problems) process.stderr.write(`  - ${problem}\n`);
    process.exit(1);
  }

  const pageShots = PAGES.length * VIEWPORTS.length * 2;
  const zoomShots = ELEMENTS.length * 2;
  process.stdout.write(
    `Captured ${pageShots} page screenshots and ${zoomShots} close-ups to ${OUT}\n` +
      `Look at ${zoomDir} — layout bugs show up in the page shots, ` +
      `rendering bugs only show up in the close-ups.\n`,
  );
}

main().catch((error) => {
  process.stderr.write(`${error.stack}\n`);
  process.exit(1);
});
