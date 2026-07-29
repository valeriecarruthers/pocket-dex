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

/** Transparent 1x1 PNG, used when a sprite genuinely cannot be fetched. */
const BLANK_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "base64",
);

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
          if (message.type() === "error") {
            problems.push(`console error on ${label}: ${message.text()}`);
          }
        });
        tab.on("pageerror", (error) => {
          problems.push(`page error on ${label}: ${error.message}`);
        });
        tab.on("requestfailed", (request) => {
          // Only same-origin failures indicate a bug in the app itself.
          if (request.url().startsWith(BASE)) {
            problems.push(`request failed on ${label}: ${request.url()}`);
          }
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

  await browser.close();

  if (problems.length > 0) {
    process.stderr.write(`\n${problems.length} problem(s):\n`);
    for (const problem of problems) process.stderr.write(`  - ${problem}\n`);
    process.exit(1);
  }

  process.stdout.write(
    `Captured ${PAGES.length * VIEWPORTS.length * 2} screenshots to ${OUT}\n`,
  );
}

main().catch((error) => {
  process.stderr.write(`${error.stack}\n`);
  process.exit(1);
});
