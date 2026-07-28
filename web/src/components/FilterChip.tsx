"use client";

/** Selectable pill used across the gallery filter bar. Port of FilterChip.swift. */
export function FilterChip({
  label,
  selected,
  onClick,
  color,
}: {
  label: string;
  selected: boolean;
  onClick: () => void;
  color?: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={selected}
      className={`shrink-0 rounded-full border px-3 py-1 text-xs font-medium transition ${
        selected
          ? "border-transparent text-white"
          : "border-border bg-surface text-muted hover:text-foreground"
      }`}
      style={selected ? { backgroundColor: color ?? "var(--accent)" } : undefined}
    >
      {label}
    </button>
  );
}
