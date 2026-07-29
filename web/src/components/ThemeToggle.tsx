"use client";

import { useCallback, useSyncExternalStore } from "react";

/**
 * Appearance toggle, the web counterpart of the iOS Settings appearance picker.
 *
 * The `dark` class is applied by an inline script in the layout before first
 * paint, so the theme never flashes. That makes the class an external store this
 * component reads rather than owns — hence useSyncExternalStore, which also gives
 * the correct server snapshot instead of guessing and then correcting in an effect.
 */
function subscribe(onChange: () => void) {
  const observer = new MutationObserver(onChange);
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["class"],
  });
  return () => observer.disconnect();
}

function getSnapshot() {
  return document.documentElement.classList.contains("dark");
}

/** The server has no DOM; the inline script corrects this before paint. */
function getServerSnapshot() {
  return false;
}

export function ThemeToggle() {
  const isDark = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  const toggle = useCallback(() => {
    const next = !document.documentElement.classList.contains("dark");
    document.documentElement.classList.toggle("dark", next);
    try {
      localStorage.setItem("pocketdex-theme", next ? "dark" : "light");
    } catch {
      // Private browsing can reject writes; the toggle still works for this session.
    }
  }, []);

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={`Switch to ${isDark ? "light" : "dark"} appearance`}
      className="flex h-9 w-9 items-center justify-center rounded-full border border-border bg-surface text-muted transition hover:text-foreground"
    >
      {isDark ? (
        <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden="true">
          <path d="M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10Zm0 2.5a1 1 0 0 1 1 1V22a1 1 0 1 1-2 0v-1.5a1 1 0 0 1 1-1Zm0-19a1 1 0 0 1 1 1V3a1 1 0 1 1-2 0V1.5a1 1 0 0 1 1-1ZM22 11a1 1 0 1 1 0 2h-1.5a1 1 0 1 1 0-2H22ZM3.5 11a1 1 0 1 1 0 2H2a1 1 0 1 1 0-2h1.5Zm15.4-6.9a1 1 0 0 1 0 1.4l-1.1 1.1a1 1 0 1 1-1.4-1.4l1.1-1.1a1 1 0 0 1 1.4 0ZM6.6 16.4a1 1 0 0 1 0 1.4l-1.1 1.1a1 1 0 0 1-1.4-1.4l1.1-1.1a1 1 0 0 1 1.4 0Zm12.3 2.5a1 1 0 0 1-1.4 0l-1.1-1.1a1 1 0 0 1 1.4-1.4l1.1 1.1a1 1 0 0 1 0 1.4ZM6.6 7.6a1 1 0 0 1-1.4 0L4.1 6.5a1 1 0 0 1 1.4-1.4l1.1 1.1a1 1 0 0 1 0 1.4Z" />
        </svg>
      ) : (
        <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden="true">
          <path d="M21.5 14.1A9 9 0 1 1 9.9 2.5a1 1 0 0 1 1.3 1.3 7 7 0 0 0 9 9 1 1 0 0 1 1.3 1.3Z" />
        </svg>
      )}
    </button>
  );
}
