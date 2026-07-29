"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

/** Bottom tab bar on small screens, inline nav on wide ones. Mirrors RootView.swift. */
const TABS = [
  {
    href: "/",
    label: "Pokédex",
    match: (path: string) => path === "/" || path.startsWith("/pokemon"),
    icon: (
      <path d="M12 2a10 10 0 0 0-9.95 9h6.03a4 4 0 0 1 7.84 0h6.03A10 10 0 0 0 12 2Zm9.95 11h-6.03a4 4 0 0 1-7.84 0H2.05A10 10 0 0 0 22 13ZM12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" />
    ),
  },
  {
    href: "/types",
    label: "Type Chart",
    match: (path: string) => path.startsWith("/types"),
    icon: (
      <path d="M4 4h7v7H4V4Zm9 0h7v7h-7V4ZM4 13h7v7H4v-7Zm9 0h7v7h-7v-7Z" />
    ),
  },
  {
    href: "/about",
    label: "About",
    match: (path: string) => path.startsWith("/about"),
    icon: (
      <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 5a1.25 1.25 0 1 1 0 2.5A1.25 1.25 0 0 1 12 7Zm1.5 10h-3a1 1 0 1 1 0-2h.5v-3H10a1 1 0 1 1 0-2h1.5a1 1 0 0 1 1 1v4h1a1 1 0 1 1 0 2Z" />
    ),
  },
];

export function TabBar() {
  const pathname = usePathname();

  return (
    <nav
      aria-label="Primary"
      className="fixed inset-x-0 bottom-0 z-40 border-t border-border bg-surface/95 backdrop-blur sm:static sm:border-t-0 sm:bg-transparent sm:backdrop-blur-none"
    >
      <ul className="mx-auto flex max-w-6xl items-center justify-around px-2 py-1.5 sm:justify-start sm:gap-1 sm:px-0 sm:py-0">
        {TABS.map((tab) => {
          const active = tab.match(pathname);
          return (
            <li key={tab.href}>
              <Link
                href={tab.href}
                aria-current={active ? "page" : undefined}
                className={`flex flex-col items-center gap-0.5 rounded-lg px-3 py-1.5 text-[11px] font-medium transition sm:flex-row sm:gap-2 sm:text-sm ${
                  active
                    ? "text-accent sm:bg-surface-muted"
                    : "text-muted hover:text-foreground"
                }`}
              >
                <svg viewBox="0 0 24 24" className="h-5 w-5 sm:h-4 sm:w-4" fill="currentColor" aria-hidden="true">
                  {tab.icon}
                </svg>
                {tab.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
