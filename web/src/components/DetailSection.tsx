/** Titled card wrapping a block of detail content. Port of DetailSection.swift. */
export function DetailSection({
  title,
  children,
  className = "",
}: {
  title: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section className={`rounded-2xl border border-border bg-surface p-4 ${className}`}>
      <h2 className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted">{title}</h2>
      {children}
    </section>
  );
}

/** Small labelled value tile. Port of StatCard.swift. */
export function StatCard({ title, value }: { title: string; value: string }) {
  return (
    <div className="flex min-h-[72px] flex-col justify-between gap-1 rounded-xl bg-surface-muted p-3">
      <span className="text-[11px] text-muted">{title}</span>
      <span className="text-sm font-semibold leading-tight">{value}</span>
    </div>
  );
}
