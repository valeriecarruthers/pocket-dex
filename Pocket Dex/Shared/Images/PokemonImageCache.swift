//
//  PokemonImageCache.swift
//  Pocket Dex
//
//  In-memory + on-disk image cache so scrolling back is instant and seen images never re-download.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: platformImage)
        #endif
    }
}

/// Loads Pokemon images with an in-memory + on-disk cache so scrolling back is instant
/// and already-seen images never re-download.
final class PokemonImageCache {
    static let shared = PokemonImageCache()

    private let memory = NSCache<NSURL, PlatformImage>()
    private let session: URLSession

    private init() {
        memory.countLimit = 600
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 40 * 1024 * 1024,
            diskCapacity: 400 * 1024 * 1024,
            diskPath: "PokeAPIImages"
        )
        session = URLSession(configuration: configuration)
    }

    func cachedImage(for url: URL) -> PlatformImage? {
        memory.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> PlatformImage? {
        if let cached = cachedImage(for: url) { return cached }
        guard let (data, _) = try? await session.data(from: url),
              let image = PlatformImage(data: data) else { return nil }
        memory.setObject(image, forKey: url as NSURL)
        return image
    }
}
