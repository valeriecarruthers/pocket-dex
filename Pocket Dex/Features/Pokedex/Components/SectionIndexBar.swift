//
//  SectionIndexBar.swift
//  Pocket Dex
//
//  A Contacts-style vertical index for fast-scrolling the gallery; drag or tap to jump.
//

import SwiftUI

struct GalleryIndexEntry: Identifiable {
    let id: Int
    let label: String
    let targetPokemonID: Int
}

struct SectionIndexBar: View {
    let entries: [GalleryIndexEntry]
    let verticalLabels: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 1) {
                ForEach(entries) { entry in
                    Text(entry.label)
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.tint)
                        .fixedSize()
                        .rotationEffect(.degrees(verticalLabels ? 90 : 0))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !entries.isEmpty, geo.size.height > 0 else { return }
                        let fraction = value.location.y / geo.size.height
                        let index = min(entries.count - 1, max(0, Int(fraction * CGFloat(entries.count))))
                        onSelect(entries[index].targetPokemonID)
                    }
            )
        }
        .frame(width: verticalLabels ? 18 : 30)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .padding(.vertical, 8)
    }
}
