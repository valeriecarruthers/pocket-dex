/**
 * health-check.mjs
 *
 * Verifies the deployed site is actually serving a working Pokédex, not just
 * returning 200 from a CDN.
 *
 * A status code alone is a weak signal for a static site: a broken build can
 * still serve an empty shell, and a wiped dataset would render a page with no
 * Pokémon on it. Each check therefore asserts on content that only appears when
 * the thing behind it genuinely worked.
 *
 * Usage:
 *   node scripts/health-check.mjs [--base https://pocket-dex-vc.vercel.app]
 *
 * Exits 0 when everything passes, 1 when anything fails. Writes a Markdown
 * summary to stdout so a workflow can put it straight into an issue.
 */

const DEFAULT_BASE = "https://pocket-dex-vc.vercel.app";

function arg(flag, fallback) {
  const i = process.argv.indexOf(flag);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const BASE = (arg("--base", process.env.SITE_URL || DEFAULT_BASE)).replace(/\/$/, "");
const TIMEOUT_MS = 20_000;

/**
 * Each `expect` is chosen to fail if the layer behind it broke:
 * the gallery proves the dataset shipped, a detail page proves static
 * generation ran, and the About page proves the disclaimer is still live.
 */
const CHECKS = [
  {
    path: "/",
    name: "Gallery",
    expect: ["Pokédex", "Bulbasaur", "Charizard"],
  },
  {
    path: "/pokemon/pikachu",
    name: "Detail page",
    expect: ["Pikachu", "#0025", "electric"],
  },
  {
    path: "/types",
    name: "Type chart",
    expect: ["Type Chart", "Fighting"],
  },
  {
    path: "/about",
    name: "About and disclaimer",
    expect: ["personal portfolio project", "not affiliated"],
  },
];

async function check({ path: urlPath, name, expect }) {
  const url = `${BASE}${urlPath}`;
  const started = Date.now();

  try {
    const response = await fetch(url, {
      signal: AbortSignal.timeout(TIMEOUT_MS),
      headers: { "user-agent": "pocket-dex-health-check" },
      redirect: "follow",
    });
    const ms = Date.now() - started;

    if (!response.ok) {
      return { name, url, ok: false, ms, reason: `HTTP ${response.status}` };
    }

    const body = await response.text();
    const missing = expect.filter(
      (needle) => !body.toLowerCase().includes(needle.toLowerCase()),
    );

    if (missing.length > 0) {
      return {
        name,
        url,
        ok: false,
        ms,
        reason: `served 200 but missing: ${missing.join(", ")}`,
      };
    }

    return { name, url, ok: true, ms };
  } catch (error) {
    return {
      name,
      url,
      ok: false,
      ms: Date.now() - started,
      reason: error.name === "TimeoutError" ? `no response in ${TIMEOUT_MS}ms` : error.message,
    };
  }
}

async function main() {
  const results = await Promise.all(CHECKS.map(check));
  const failures = results.filter((r) => !r.ok);

  const lines = [`Checked \`${BASE}\``, ""];
  lines.push("| Check | Result | Time |");
  lines.push("|---|---|---|");
  for (const r of results) {
    lines.push(`| ${r.name} | ${r.ok ? "✅ pass" : `❌ ${r.reason}`} | ${r.ms} ms |`);
  }
  lines.push("");

  if (failures.length > 0) {
    lines.push(`**${failures.length} of ${results.length} checks failed.**`, "");
    for (const f of failures) {
      lines.push(`- \`${f.url}\` — ${f.reason}`);
    }
    lines.push("");
  }

  process.stdout.write(lines.join("\n"));
  process.exit(failures.length > 0 ? 1 : 0);
}

main().catch((error) => {
  process.stderr.write(`${error.stack}\n`);
  process.exit(1);
});
