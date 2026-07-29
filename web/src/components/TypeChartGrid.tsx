import Link from "next/link";

import {
  POKEMON_TYPES,
  attackMultiplier,
  effectivenessLabel,
  typeAbbreviation,
  typeColor,
} from "@/lib/pokemon-type";

/**
 * The full 18x18 matchup grid, read as attacker (row) against defender (column).
 * Port of TypeChartGrid.swift.
 */
export function TypeChartGrid() {
  return (
    <div className="overflow-x-auto">
      <table className="border-separate border-spacing-0.5 text-[10px]">
        <caption className="sr-only">
          Type effectiveness chart. Rows are attacking types, columns are defending types.
        </caption>
        <thead>
          <tr>
            <th scope="col" className="sticky left-0 z-10 bg-background p-1">
              <span className="sr-only">Attacking type</span>
            </th>
            {POKEMON_TYPES.map((defender) => (
              <th key={defender} scope="col" className="p-0">
                <span
                  className="flex h-6 w-8 items-center justify-center rounded font-semibold text-white"
                  style={{ backgroundColor: typeColor(defender) }}
                  title={defender}
                >
                  {typeAbbreviation(defender)}
                </span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {POKEMON_TYPES.map((attacker) => (
            <tr key={attacker}>
              <th scope="row" className="sticky left-0 z-10 bg-background p-0 pr-1">
                <Link
                  href={`/types/${attacker}`}
                  className="flex h-6 w-14 items-center justify-center rounded font-semibold text-white transition hover:brightness-110"
                  style={{ backgroundColor: typeColor(attacker) }}
                >
                  {typeAbbreviation(attacker)}
                </Link>
              </th>
              {POKEMON_TYPES.map((defender) => {
                const multiplier = attackMultiplier(attacker, defender);
                return (
                  <td key={defender} className="p-0">
                    <span
                      title={`${attacker} → ${defender}: ${effectivenessLabel(multiplier)}×`}
                      className={`flex h-6 w-8 items-center justify-center rounded font-mono font-semibold tabular-nums ${cellClass(multiplier)}`}
                    >
                      {multiplier === 1 ? "" : effectivenessLabel(multiplier)}
                    </span>
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function cellClass(multiplier: number): string {
  switch (multiplier) {
    case 2:
      return "bg-emerald-500/85 text-white";
    case 0.5:
      return "bg-red-500/75 text-white";
    case 0:
      return "bg-foreground/70 text-background";
    default:
      return "bg-surface-muted text-muted";
  }
}
