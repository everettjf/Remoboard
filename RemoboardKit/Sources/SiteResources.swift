//
//  SiteResources.swift
//  RemoboardKit
//
//  Loads the bundled single-page web UI that ships inside the framework and
//  builds a ready-to-run server from it.
//

import Foundation

private final class KitBundleMarker {}

public enum SiteResources {
    static var bundle: Bundle { Bundle(for: KitBundleMarker.self) }

    public static func indexHTML() -> Data {
        if let url = bundle.url(forResource: "index", withExtension: "html"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        // Fallback so the server never serves an empty page during development.
        return Data("<!doctype html><meta charset=utf-8><title>Remoboard</title><body>Web UI missing.</body>".utf8)
    }

    public static func favicon() -> Data? {
        guard let url = bundle.url(forResource: "favicon", withExtension: "ico") else { return nil }
        return try? Data(contentsOf: url)
    }
}

public extension RemoServer {
    /// Builds a server preloaded with the bundled web UI.
    static func make(port: UInt16) -> RemoServer {
        RemoServer(port: port, html: SiteResources.indexHTML(), favicon: SiteResources.favicon())
    }
}
