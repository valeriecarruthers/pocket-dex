//
//  FlowLayout.swift
//  Pocket Dex
//
//  Lays content in a horizontal row that wraps to a grid when it can't fit.
//

import SwiftUI

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: spacing) { content }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: spacing)], alignment: .leading, spacing: spacing) { content }
            }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: spacing)], alignment: .leading, spacing: spacing) { content }
        }
    }
}
