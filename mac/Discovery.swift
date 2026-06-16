//
//  Discovery.swift
//  Remoboard (macOS companion)
//
//  Browses `_remoboard._tcp` on the local network and resolves a chosen service to a
//  concrete host/port so the WebSocket client can connect.
//

import Foundation
import Network

@MainActor
final class Discovery: ObservableObject {

    struct Device: Identifiable, Equatable {
        let id: String      // service name
        let name: String
        let endpoint: NWEndpoint
        static func == (a: Device, b: Device) -> Bool { a.id == b.id }
    }

    @Published var devices: [Device] = []

    private var browser: NWBrowser?

    func start() {
        stop()
        let params = NWParameters()
        params.includePeerToPeer = false
        let browser = NWBrowser(for: .bonjour(type: "_remoboard._tcp", domain: nil), using: params)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let devices = results.compactMap { result -> Device? in
                if case let .service(name, _, _, _) = result.endpoint {
                    return Device(id: name, name: name, endpoint: result.endpoint)
                }
                return nil
            }
            Task { @MainActor in self?.devices = devices.sorted { $0.name < $1.name } }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    /// Opens a throwaway TCP connection to resolve a Bonjour endpoint to host/port.
    func resolve(_ device: Device, completion: @escaping ((String, Int)?) -> Void) {
        let connection = NWConnection(to: device.endpoint, using: .tcp)
        var finished = false
        let finish: ((String, Int)?) -> Void = { result in
            guard !finished else { return }
            finished = true
            connection.cancel()
            DispatchQueue.main.async { completion(result) }
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if case let .hostPort(host, port)? = connection.currentPath?.remoteEndpoint {
                    finish((Self.string(from: host), Int(port.rawValue)))
                } else {
                    finish(nil)
                }
            case .failed, .cancelled:
                finish(nil)
            default:
                break
            }
        }
        connection.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { finish(nil) }
    }

    nonisolated private static func string(from host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let addr):
            return addr.debugDescription.components(separatedBy: "%").first ?? addr.debugDescription
        case .ipv6(let addr):
            // Preserve the %zone for link-local (fe80::) addresses — without it the address
            // is unroutable. In a URL the '%' must be percent-encoded as '%25'.
            let desc = addr.debugDescription
            if let pct = desc.firstIndex(of: "%") {
                let literal = desc[..<pct]
                let zone = desc[desc.index(after: pct)...]
                return "[\(literal)%25\(zone)]"
            }
            return "[\(desc)]"
        case .name(let name, _):
            return name
        @unknown default:
            return ""
        }
    }
}
