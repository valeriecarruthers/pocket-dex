//
//  CachedAsyncImage.swift
//  Pocket Dex
//
//  Progressive, cached artwork views backed by PokemonImageCache.
//

import SwiftUI

struct PokemonArtworkView: View {
    let url: URL?
    var lowResURL: URL? = nil
    let title: String
    var tint: Color? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.55))

            RoundedRectangle(cornerRadius: 8)
                .fill(tint?.opacity(0.18) ?? Color.clear)

            CachedAsyncImage(url: url, lowResURL: lowResURL, title: title)
                .padding(12)
        }
    }
}

/// Progressive, cached image view: shows the tiny sprite first (near-instant) then swaps in the
/// high-resolution artwork once it arrives. A cached high-res image appears immediately.
struct CachedAsyncImage: View {
    let url: URL?
    var lowResURL: URL? = nil
    let title: String

    @State private var image: PlatformImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(title)
            } else if didFail {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        image = nil
        didFail = false

        guard let url else {
            didFail = true
            return
        }

        // Instant path: high-res already decoded in memory.
        if let cached = PokemonImageCache.shared.cachedImage(for: url) {
            image = cached
            return
        }

        // Progressive preview: show the tiny sprite while the artwork downloads.
        if let lowResURL,
           PokemonImageCache.shared.cachedImage(for: url) == nil,
           let preview = await PokemonImageCache.shared.image(for: lowResURL) {
            if image == nil { image = preview }
        }

        if let full = await PokemonImageCache.shared.image(for: url) {
            image = full
        } else if image == nil {
            didFail = true
        }
    }
}
