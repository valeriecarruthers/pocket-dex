//
//  String+Formatting.swift
//  Pocket Dex
//

import Foundation

extension String {
    /// Turns a hyphenated API identifier (e.g. "zapdos-galar") into a display name ("Zapdos Galar").
    nonisolated var displayName: String {
        split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    /// Cleans PokeAPI free text of the control characters it embeds in flavor/effect strings.
    var cleanedPokeAPIText: String {
        replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\u{000C}", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }
}
