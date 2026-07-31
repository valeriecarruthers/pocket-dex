import type { Metadata } from "next";
import Link from "next/link";
import { Analytics } from "@vercel/analytics/next";

import { TabBar } from "@/components/TabBar";
import { ThemeToggle } from "@/components/ThemeToggle";

import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Pocket Dex",
    template: "%s · Pocket Dex",
  },
  description:
    "A fast, offline-friendly Pokédex covering all 1,025 species — gallery, detail pages with evolution trees and alternate forms, and the full type matchup chart.",
  openGraph: {
    title: "Pocket Dex",
    description: "A fast, offline-friendly Pokédex for all 1,025 species.",
    type: "website",
  },
};

/**
 * Applied before first paint so the stored theme never flashes. Kept inline and
 * tiny for that reason — it has to run ahead of the rest of the bundle.
 */
const THEME_SCRIPT = `
try {
  var stored = localStorage.getItem('pocketdex-theme');
  var dark = stored ? stored === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
  if (dark) document.documentElement.classList.add('dark');
} catch (e) {}
`;

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className="h-full" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_SCRIPT }} />
      </head>
      <body className="flex min-h-full flex-col">
        <header className="sticky top-0 z-30 border-b border-border bg-background/85 backdrop-blur">
          <div className="mx-auto flex max-w-6xl items-center gap-4 px-4 py-3">
            <Link href="/" className="flex items-center gap-2 font-semibold tracking-tight">
              <span
                aria-hidden="true"
                className="grid h-7 w-7 place-items-center rounded-full border-2 border-foreground bg-accent"
              >
                <span className="h-2.5 w-2.5 rounded-full border-2 border-foreground bg-surface" />
              </span>
              Pocket Dex
            </Link>

            <div className="hidden sm:block">
              <TabBar />
            </div>

            <div className="ml-auto">
              <ThemeToggle />
            </div>
          </div>
        </header>

        <main className="mx-auto w-full max-w-6xl flex-1 px-4 pb-24 pt-6 sm:pb-10">
          {children}
        </main>

        <footer className="mx-auto w-full max-w-6xl px-4 pb-24 pt-4 text-xs leading-relaxed text-muted sm:pb-8">
          <p>
            Pocket Dex is a personal portfolio project built to demonstrate software
            development skills. It is non-commercial and is not intended for commercial
            distribution or general public use.
          </p>
          <p className="mt-1.5">
            Not affiliated with, endorsed by, or sponsored by Nintendo, Game Freak, or The
            Pokémon Company. Pokémon and all related names, characters, and artwork are
            trademarks and copyrights of their respective owners. Data from{" "}
            <a
              href="https://pokeapi.co"
              className="underline underline-offset-2 hover:text-foreground"
              target="_blank"
              rel="noreferrer"
            >
              PokeAPI
            </a>
            . <Link href="/about" className="underline underline-offset-2 hover:text-foreground">
              More about this project
            </Link>
            .
          </p>
        </footer>

        <div className="sm:hidden">
          <TabBar />
        </div>

        <Analytics />
      </body>
    </html>
  );
}
