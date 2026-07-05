//
//  TypeChartView.swift
//  Pocket Dex
//
//  The Type Chart tab. Offers two ways to read the same data:
//   • Matchups — pick a type and see its full offensive/defensive breakdown.
//   • Full Chart — the classic 18×18 grid.
//
//  Both are available everywhere, but the default follows the screen: the grid suits the
//  space on iPad/Mac, while the focused matchup view reads better on a phone. Selecting a
//  type from the grid jumps to its matchup breakdown.
//

import SwiftUI

struct TypeChartView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedType: PokemonType = .fire
    // nil until the user picks a mode, so we can fall back to the size-class default.
    @State private var mode: ChartMode?

    enum ChartMode: String, CaseIterable, Identifiable {
        case matchups, grid
        var id: Self { self }
        var title: String {
            switch self {
            case .matchups: "Matchups"
            case .grid: "Full Chart"
            }
        }
    }

    // The mode actually shown: an explicit user choice, or the device-appropriate default.
    private var effectiveMode: ChartMode {
        mode ?? (sizeClass == .regular ? .grid : .matchups)
    }

    private var modeBinding: Binding<ChartMode> {
        Binding(get: { effectiveMode }, set: { mode = $0 })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: modeBinding) {
                    ForEach(ChartMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                modeContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Type Chart")
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch effectiveMode {
        case .matchups:
            typeSelector
            Divider()
            TypeMatchupDetail(type: selectedType)
        case .grid:
            TypeChartGrid { type in
                selectedType = type
                mode = .matchups
            }
        }
    }

    // A wrapping grid of type badges; the active one is highlighted. Wraps to as many rows
    // as it needs so every type stays visible without horizontal scrolling.
    private var typeSelector: some View {
        FlowLayout(spacing: 8) {
            ForEach(PokemonType.allCases) { type in
                Button {
                    selectedType = type
                } label: {
                    TypeBadge(type: type)
                        .opacity(type == selectedType ? 1 : 0.4)
                        .overlay {
                            if type == selectedType {
                                Capsule().stroke(.primary, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

#Preview {
    TypeChartView()
}
