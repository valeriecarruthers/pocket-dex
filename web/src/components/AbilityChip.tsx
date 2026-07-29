"use client";

import { useEffect, useRef, useState } from "react";

import { abilityColor } from "@/lib/format";
import type { AbilityInfo } from "@/lib/types";

/**
 * Ability pill that reveals its description on tap.
 * Port of AbilityChip.swift, whose iOS version uses a popover.
 */
export function AbilityChip({
  name,
  isHidden,
  info,
}: {
  name: string;
  isHidden: boolean;
  info?: AbilityInfo;
}) {
  const [open, setOpen] = useState(false);
  const container = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!open) return;

    function onPointerDown(event: MouseEvent) {
      if (!container.current?.contains(event.target as Node)) setOpen(false);
    }
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }

    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  const label = info?.displayName ?? name;
  const description = info?.description;

  return (
    <div ref={container} className="relative">
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        aria-expanded={open}
        disabled={!description}
        className="flex items-center gap-1.5 rounded-full border border-border bg-surface-muted px-3 py-1.5 text-xs font-medium transition hover:border-transparent disabled:cursor-default"
      >
        <span
          aria-hidden="true"
          className="h-2 w-2 rounded-full"
          style={{ backgroundColor: abilityColor(name) }}
        />
        {label}
        {isHidden && (
          <span className="rounded bg-foreground/10 px-1 text-[9px] uppercase tracking-wide text-muted">
            Hidden
          </span>
        )}
      </button>

      {open && description && (
        <div
          role="dialog"
          aria-label={`${label} description`}
          className="absolute left-0 top-full z-20 mt-2 w-64 rounded-xl border border-border bg-surface p-3 text-xs leading-relaxed shadow-xl"
        >
          {description}
        </div>
      )}
    </div>
  );
}
