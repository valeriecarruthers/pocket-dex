//
//  SettingsView.swift
//  Pocket Dex
//
//  The Settings tab: appearance selection, cache management, and an About section.
//  Home for themes, app-icon selection, and catch-tracking as those features land.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    // Appearance is persisted in UserDefaults via @AppStorage and read back by RootView,
    // which applies it app-wide. The binding below drives the picker directly.
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue
    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    // Combined size of the image + JSON caches. `nil` while we're first measuring it.
    @State private var cacheSize: Int?
    @State private var isClearing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: appearanceBinding) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.label).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    LabeledContent("Cached Data") {
                        if let cacheSize {
                            Text(cacheSize.formatted(.byteCount(style: .file)))
                        } else {
                            ProgressView()
                        }
                    }

                    Button(role: .destructive) {
                        clearCache()
                    } label: {
                        if isClearing {
                            ProgressView()
                        } else {
                            Text("Clear Cache")
                        }
                    }
                    .disabled(isClearing || cacheSize == 0)
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Clears downloaded sprites and Pokédex data. They'll re-download as you browse.")
                }

                Section("About") {
                    LabeledContent("Version", value: Self.versionString)
                    Link(destination: URL(string: "https://pokeapi.co")!) {
                        LabeledContent("Data Source", value: "PokéAPI")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            await refreshCacheSize()
        }
    }

    // MARK: - Cache

    // Sums the image cache's on-disk usage with the JSON cache's file sizes. The JSON size
    // lives behind an actor, so we await it off the main actor.
    private func refreshCacheSize() async {
        let imageBytes = PokemonImageCache.shared.diskUsageBytes
        let jsonBytes = (try? await PokeAPIDiskCache.shared.sizeBytes()) ?? 0
        cacheSize = imageBytes + jsonBytes + referenceStoreBytes()
    }

    private func clearCache() {
        isClearing = true
        Task {
            PokemonImageCache.shared.clear()
            try? await PokeAPIDiskCache.shared.clear()

            // Also empty the SwiftData reference store and reset the refresh clock, so the
            // gallery repopulates from scratch on its next appearance.
            let store = PokedexStore(modelContainer: modelContext.container)
            try? await store.clear()
            UserDefaults.standard.removeObject(forKey: PokedexRefresh.lastListRefreshKey)

            await refreshCacheSize()
            isClearing = false
        }
    }

    // On-disk size of the SwiftData reference store (the .store file plus its -wal/-shm sidecars).
    private func referenceStoreBytes() -> Int {
        guard let url = modelContext.container.configurations.first?.url else { return 0 }
        let fileManager = FileManager.default
        return [url.path, url.path + "-wal", url.path + "-shm"].reduce(0) { total, path in
            let size = (try? fileManager.attributesOfItem(atPath: path)[.size]) as? Int ?? 0
            return total + size
        }
    }

    // MARK: - About

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
