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
