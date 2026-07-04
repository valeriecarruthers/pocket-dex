//
//  FilterChip.swift
//  Pocket Dex
//
//  A removable, tappable chip representing an active filter.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let systemImage: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Image(systemName: "xmark.circle.fill")
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.tint.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel("Remove \(title) filter")
    }
}
