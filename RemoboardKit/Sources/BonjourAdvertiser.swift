//
//  BonjourAdvertiser.swift
//  RemoboardKit
//
//  Publishes a `_remoboard._tcp` Bonjour service so the desktop companion can discover
//  the phone on the local network. This is started by the keyboard extension alongside
//  the server (they share the same lifetime), so the advertised endpoint always points at
//  a live listener. Bonjour needs the local-network permission; if the user declines it,
//  advertising silently fails but the server still works via the manually entered IP.
//

import Foundation

public final class BonjourAdvertiser: NSObject {

    public static let serviceType = "_remoboard._tcp."

    private var service: NetService?

    public override init() { super.init() }

    public func start(name: String, port: Int) {
        stop()
        let service = NetService(domain: "local.", type: BonjourAdvertiser.serviceType, name: name, port: Int32(port))
        service.delegate = self
        service.publish()
        self.service = service
    }

    public func stop() {
        service?.stop()
        service = nil
    }
}

extension BonjourAdvertiser: NetServiceDelegate {
    public func netServiceDidPublish(_ sender: NetService) {
        NSLog("[Remoboard] Bonjour published: \(sender.name) on port \(sender.port)")
    }
    public func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        NSLog("[Remoboard] Bonjour publish failed: \(errorDict)")
    }
}
