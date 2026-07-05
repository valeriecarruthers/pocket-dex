//
//  TypeChartGrid.swift
//  Pocket Dex
//
//  The classic 18×18 effectiveness matrix. Rows are the attacking type, columns the
//  defending type, and each cell shows the damage multiplier. Tapping any type header
//  selects that type (handled by the parent, which shows its full matchup breakdown).
//
//  The grid scales to fill the space it's given: on a roomy iPad/Mac window the cells grow
//  so the whole chart fits without wasted margins, while on a phone they hold a readable
//  minimum size and the grid scrolls in both directions. Content stays top-leading.
//

import SwiftUI

struct TypeChartGrid: View {
    var onSelectType: (PokemonType) -> Void

    private let types = PokemonType.allCases
    private let spacing: CGFloat = 3
    private let minCell: CGFloat = 30
    private let maxCell: CGFloat = 68
    private let legendHeight: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let cell = cellSize(in: geo.size)
            VStack(alignment: .leading, spacing: 10) {
                ScrollView([.horizontal, .vertical]) {
                    matrix(cell: cell)
                }
                legend
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding()
    }

    // Sizes each square so the 19×19 matrix (18 types + a header) fills the smaller of the
    // available dimensions, clamped to a readable range. Below the minimum, the grid scrolls.
    private func cellSize(in size: CGSize) -> CGFloat {
        let count = CGFloat(types.count + 1)
        let side = min(size.width, size.height - legendHeight - 10)
        let fitted = (side - spacing * (count - 1)) / count
        return min(maxCell, max(minCell, fitted))
    }

    private func matrix(cell: CGFloat) -> some View {
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            GridRow {
                cornerHint(cell: cell)
                ForEach(types) { typeHeader($0, cell: cell) }
            }
            ForEach(types) { attacker in
                GridRow {
                    typeHeader(attacker, cell: cell)
                    ForEach(types) { defender in
                        valueCell(attacker.attackMultiplier(against: defender), cell: cell)
                    }
                }
            }
        }
    }

    private func cornerHint(cell: CGFloat) -> some View {
        Text("ATK↓\nDEF→")
            .font(.system(size: cell * 0.22, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: cell, height: cell)
    }

    private func typeHeader(_ type: PokemonType, cell: CGFloat) -> some View {
        Button {
            onSelectType(type)
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(type.color)
                .frame(width: cell, height: cell)
                .overlay {
                    Text(type.abbreviation)
                        .font(.system(size: cell * 0.28, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
    }

    private func valueCell(_ multiplier: Double, cell: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color(for: multiplier))
            .frame(width: cell, height: cell)
            .overlay {
                // Leave neutral (1×) cells blank so the meaningful matchups stand out.
                if multiplier != 1 {
                    Text(PokemonType.effectivenessLabel(multiplier))
                        .font(.system(size: cell * 0.38, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
    }

    private func color(for multiplier: Double) -> Color {
        switch multiplier {
        case 0: .black.opacity(0.72)
        case 0.5: .red.opacity(0.62)
        case 2: .green.opacity(0.7)
        default: Color.gray.opacity(0.22)   // cross-platform neutral (works on macOS)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color(for: 2), "2× Super effective")
            legendItem(color(for: 0.5), "½× Resisted")
            legendItem(color(for: 0), "0× No effect")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
        }
    }
}

#Preview {
    TypeChartGrid { _ in }
}
