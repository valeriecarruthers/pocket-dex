import type { Metadata } from "next";

import { DetailSection, StatCard } from "@/components/DetailSection";
import { meta } from "@/lib/dataset";

export const metadata: Metadata = {
  title: "About",
  description: "How Pocket Dex is built, and where its data comes from.",
};

export default function AboutPage() {
  const generated = new Date(meta.generatedAt);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">About</h1>
        <p className="mt-1 text-sm text-muted">
          The web counterpart to Pocket Dex, a SwiftUI iOS app in the same repository.
        </p>
      </div>

      <DetailSection title="Dataset">
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          <StatCard title="Species" value={meta.counts.species.toLocaleString()} />
          <StatCard title="Forms" value={meta.counts.varieties.toLocaleString()} />
          <StatCard title="Evolution chains" value={meta.counts.evolutionChains.toLocaleString()} />
          <StatCard title="Abilities" value={meta.counts.abilities.toLocaleString()} />
          <StatCard title="Games" value={meta.counts.games.toLocaleString()} />
          <StatCard
            title="Generated"
            value={generated.toISOString().slice(0, 10)}
          />
        </div>

        <p className="mt-3 text-xs leading-relaxed text-muted">
          Built from{" "}
          <a
            href={`https://github.com/${meta.sourceRepo}/tree/${meta.sourceRef}`}
            className="underline underline-offset-2 hover:text-foreground"
            target="_blank"
            rel="noreferrer"
          >
            {meta.sourceRepo}
          </a>{" "}
          pinned at{" "}
          <code className="rounded bg-surface-muted px-1 py-0.5 font-mono">
            {meta.sourceRef.slice(0, 12)}
          </code>
          . Pinning to a commit makes rebuilds reproducible and reduces &ldquo;has upstream
          changed?&rdquo; to a single SHA comparison.
        </p>
      </DetailSection>

      <DetailSection title="How it is built">
        <ul className="flex flex-col gap-2 text-sm leading-relaxed">
          <li>
            <strong className="font-semibold">Static by default.</strong> A build-time script
            pulls PokeAPI once and commits the result. Every page — including all{" "}
            {meta.counts.species.toLocaleString()} species pages — is prerendered, so there are no
            API calls at runtime and nothing breaks if PokeAPI has a bad day.
          </li>
          <li>
            <strong className="font-semibold">Shared domain logic.</strong> The type chart,
            regions, and formatting rules are ports of the Swift originals, expressed once from
            the attacker&rsquo;s point of view with the defensive view derived from it.
          </li>
          <li>
            <strong className="font-semibold">Kept current by an agent.</strong> A scheduled
            skill compares the pinned commit against upstream, regenerates the dataset when it
            moves, and opens a pull request describing what changed.
          </li>
        </ul>
      </DetailSection>
    </div>
  );
}
