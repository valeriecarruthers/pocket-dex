//
//  DetailSection.swift
//  Pocket Dex
//
//  A titled content section used throughout the detail screens.
//

import SwiftUI

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            content
        }
    }
}
