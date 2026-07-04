//
//  SettingsView.swift
//  Pocket Dex
//
//  The Settings tab. Minimal for now — an About section reflecting the running build —
//  and the home for themes, app-icon selection, and catch-tracking as those features land.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("About") {
                    LabeledContent("Version", value: Self.versionString)
                }
            }
            .navigationTitle("Settings")
        }
    }

    // The app's marketing version and build number, read from the running bundle
    // (e.g. "1.0 (3)"). Falls back gracefully if either key is missing.
    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String
        guard let build else { return short }
        return "\(short) (\(build))"
    }
}

#Preview {
    SettingsView()
}
