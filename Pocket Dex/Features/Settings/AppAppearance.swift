//
//  AppAppearance.swift
//  Pocket Dex
//
//  The user's chosen app-wide appearance. Persisted via @AppStorage under `appearanceKey`
//  and applied at the app root with `.preferredColorScheme`.
//

import SwiftUI

/// The three appearance choices offered in Settings. Raw values are stable strings so they
/// can be stored directly in @AppStorage (UserDefaults) without a custom coder.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    /// The @AppStorage / UserDefaults key both Settings and the app root read from.
    static let storageKey = "appearance"

    var id: String { rawValue }

    /// The label shown in the Settings picker.
    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// The ColorScheme to force, or `nil` to follow the system setting.
    /// `preferredColorScheme(nil)` means "don't override", which is exactly what `.system` wants.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
