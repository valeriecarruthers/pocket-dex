//
//  PokeAPIDiskCache.swift
//  Pocket Dex
//
//  A tiny on-disk cache for PokeAPI JSON responses, keyed by request URL.
//

import Foundation

actor PokeAPIDiskCache {
    static let shared = PokeAPIDiskCache()

    private let directory: URL
    private let fileManager = FileManager.default

    private init() {
        let baseDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = baseDirectory.appending(path: "PokeAPIResponses", directoryHint: .isDirectory)
    }

    func data(for url: URL) throws -> Data? {
        try prepareDirectory()

        let fileURL = fileURL(for: url)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try Data(contentsOf: fileURL)
    }

    func save(_ data: Data, for url: URL) throws {
        try prepareDirectory()
        try data.write(to: fileURL(for: url), options: .atomic)
    }

    /// Total size of all cached JSON responses, in bytes, for display in Settings.
    /// Returns 0 if the cache directory doesn't exist yet.
    func sizeBytes() throws -> Int {
        guard fileManager.fileExists(atPath: directory.path) else { return 0 }
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        return try contents.reduce(0) { total, fileURL in
            let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            return total + size
        }
    }

    /// Removes all cached JSON responses. The directory is recreated lazily on the next save.
    func clear() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for url: URL) -> URL {
        let key = Data(url.absoluteString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directory.appending(path: key).appendingPathExtension("json")
    }
}
