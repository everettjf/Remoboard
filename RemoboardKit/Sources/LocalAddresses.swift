//
//  LocalAddresses.swift
//  RemoboardKit
//
//  Enumerates the device's IPv4 addresses so the keyboard can tell the user
//  which URL to open from their computer. Ported from the legacy `Util getAllIPAddress`.
//

import Foundation

public struct NetworkAddress {
    public let interface: String   // e.g. "en0"
    public let ip: String          // e.g. "192.168.1.20"
}

public enum LocalAddresses {

    /// All non-loopback IPv4 addresses, keyed by interface name.
    public static func ipv4() -> [NetworkAddress] {
        var result: [NetworkAddress] = []
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return result }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            let addr = ptr.pointee
            let family = addr.ifa_addr?.pointee.sa_family
            if family == UInt8(AF_INET), let saddr = addr.ifa_addr {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let res = getnameinfo(
                    saddr, socklen_t(saddr.pointee.sa_len),
                    &host, socklen_t(host.count),
                    nil, 0, NI_NUMERICHOST
                )
                if res == 0 {
                    let ip = String(cString: host)
                    let name = String(cString: addr.ifa_name)
                    if ip != "127.0.0.1" {
                        result.append(NetworkAddress(interface: name, ip: ip))
                    }
                }
            }
            cursor = addr.ifa_next
        }
        return result
    }

    /// Best guess for the primary address users should connect to.
    /// Prefers Wi-Fi (en0), then cellular (pdp_ip0), then anything else.
    public static func primaryIPv4() -> NetworkAddress? {
        let all = ipv4()
        if let wifi = all.first(where: { $0.interface == "en0" }) { return wifi }
        if let cell = all.first(where: { $0.interface == "pdp_ip0" }) { return cell }
        return all.first
    }
}
