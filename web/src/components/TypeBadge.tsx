import Link from "next/link";

import { displayNameOf } from "@/lib/format";
import { typeColor } from "@/lib/pokemon-type";

/** Coloured type capsule. Port of TypeCapsule.swift / TypeBadge.swift. */
export function TypeBadge({
  type,
  size = "md",
  href,
}: {
  type: string;
  size?: "sm" | "md";
  href?: string;
}) {
  const className = [
    "inline-flex items-center justify-center rounded-full font-semibold uppercase tracking-wide text-white",
    size === "sm" ? "px-2 py-0.5 text-[10px]" : "px-3 py-1 text-xs",
    href ? "transition hover:brightness-110" : "",
  ].join(" ");

  const style = { backgroundColor: typeColor(type) };
  const label = displayNameOf(type);

  if (href) {
    return (
      <Link href={href} className={className} style={style}>
        {label}
      </Link>
    );
  }

  return (
    <span className={className} style={style}>
      {label}
    </span>
  );
}
