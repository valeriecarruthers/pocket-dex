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
    // Held as a property so Settings can report its disk usage and clear it. It's the same
    // URLCache handed to the session's configuration below.
    private let urlCache: URLCache

    private init() {
        memory.countLimit = 600
        urlCache = URLCache(
            memoryCapacity: 40 * 1024 * 1024,
            diskCapacity: 400 * 1024 * 1024,
            diskPath: "PokeAPIImages"
        )
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = urlCache
        session = URLSession(configuration: configuration)
    }

    /// Current on-disk size of downloaded images, in bytes, for display in Settings.
    var diskUsageBytes: Int {
        urlCache.currentDiskUsage
    }

    /// Empties both the in-memory and on-disk image caches. Images re-download on next view.
    func clear() {
        memory.removeAllObjects()
        urlCache.removeAllCachedResponses()
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
