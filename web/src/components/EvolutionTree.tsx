import Image from "next/image";
import Link from "next/link";

import { formattedPokedexNumber, spriteURL } from "@/lib/format";
import { displayNameOf } from "@/lib/regions";
import type { EvolutionNode } from "@/lib/types";

/**
 * Renders an evolution family. Branching families (Eevee, Wurmple) fan out
 * horizontally at the branch point. Port of EvolutionTreeView.swift.
 */
export function EvolutionTree({
  nodes,
  currentId,
}: {
  nodes: EvolutionNode[];
  currentId: number;
}) {
  if (nodes.length === 0) {
    return <p className="text-sm text-muted">No evolution data.</p>;
  }

  return (
    <div className="flex flex-col gap-3">
      {nodes.map((node) => (
        <EvolutionBranch key={node.id} node={node} currentId={currentId} />
      ))}
    </div>
  );
}

function EvolutionBranch({ node, currentId }: { node: EvolutionNode; currentId: number }) {
  return (
    <div className="flex items-center gap-2">
      <EvolutionStage node={node} currentId={currentId} />

      {node.children.length > 0 && (
        <>
          <span aria-hidden="true" className="text-muted">
            →
          </span>
          <div className="flex flex-col gap-2">
            {node.children.map((child) => (
              <div key={child.id} className="flex items-center gap-2">
                {child.requirement && (
                  <span className="whitespace-nowrap rounded-full bg-surface-muted px-2 py-0.5 text-[10px] text-muted">
                    {child.requirement}
                  </span>
                )}
                <EvolutionBranch node={child} currentId={currentId} />
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function EvolutionStage({ node, currentId }: { node: EvolutionNode; currentId: number }) {
  const isCurrent = node.id === currentId;

  return (
    <Link
      href={`/pokemon/${node.name}`}
      aria-current={isCurrent ? "page" : undefined}
      className={`flex w-20 shrink-0 flex-col items-center gap-1 rounded-xl border p-2 transition ${
        isCurrent
          ? "border-accent bg-surface-muted"
          : "border-transparent hover:border-border hover:bg-surface-muted"
      }`}
    >
      <Image
        src={spriteURL(node.id)}
        alt={displayNameOf(node.name)}
        width={56}
        height={56}
        loading="lazy"
        className="pixelated h-14 w-14 object-contain"
      />
      <span className="font-mono text-[9px] tabular-nums text-muted">
        {formattedPokedexNumber(node.id)}
      </span>
      <span className="text-center text-[11px] font-medium leading-tight">
        {displayNameOf(node.name)}
      </span>
    </Link>
  );
}
