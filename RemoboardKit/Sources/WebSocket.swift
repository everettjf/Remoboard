//
//  WebSocket.swift
//  RemoboardKit
//
//  Minimal RFC 6455 server-side WebSocket support: the opening handshake plus a
//  streaming frame decoder and a text/control frame encoder. Only what a small
//  keyboard relay needs — no extensions, no compression.
//

import Foundation
import CryptoKit

public enum WebSocketOpcode: UInt8 {
    case continuation = 0x0
    case text = 0x1
    case binary = 0x2
    case close = 0x8
    case ping = 0x9
    case pong = 0xA
}

public struct WebSocketFrame {
    public let fin: Bool
    public let opcode: WebSocketOpcode
    public let payload: Data
}

public enum WebSocketHandshake {
    private static let magicGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    /// Computes the `Sec-WebSocket-Accept` value for a client key.
    public static func acceptValue(forKey key: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data((key + magicGUID).utf8))
        return Data(digest).base64EncodedString()
    }

    /// Full HTTP 101 response bytes for a successful upgrade.
    public static func response(forKey key: String) -> Data {
        let accept = acceptValue(forKey: key)
        let lines = [
            "HTTP/1.1 101 Switching Protocols",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Accept: \(accept)",
            "", "",
        ]
        return Data(lines.joined(separator: "\r\n").utf8)
    }
}

/// Builds outbound (server → client) frames. Server frames are never masked.
public enum WebSocketEncoder {

    public static func text(_ string: String) -> Data {
        frame(opcode: .text, payload: Data(string.utf8))
    }

    public static func pong(_ payload: Data) -> Data {
        frame(opcode: .pong, payload: payload)
    }

    public static func close() -> Data {
        frame(opcode: .close, payload: Data())
    }

    public static func frame(opcode: WebSocketOpcode, payload: Data) -> Data {
        var bytes = Data()
        bytes.append(0x80 | opcode.rawValue) // FIN + opcode

        let length = payload.count
        if length < 126 {
            bytes.append(UInt8(length))
        } else if length <= 0xFFFF {
            bytes.append(126)
            bytes.append(UInt8((length >> 8) & 0xFF))
            bytes.append(UInt8(length & 0xFF))
        } else {
            bytes.append(127)
            let len = UInt64(length)
            for shift in stride(from: 56, through: 0, by: -8) {
                bytes.append(UInt8((len >> UInt64(shift)) & 0xFF))
            }
        }
        bytes.append(payload)
        return bytes
    }
}

/// Incremental decoder. Feed it bytes as they arrive; pull complete frames out.
///
/// Uses a read cursor instead of copying/`removeFirst`-ing the whole buffer per frame,
/// so parsing a burst of small frames is linear, not quadratic. Rejects oversized frames
/// (and runaway buffering) up front so a hostile client can't exhaust the extension's
/// memory budget.
public final class WebSocketDecoder {
    private var buffer = Data()
    private var cursor = 0

    /// Largest single frame payload we will accept (defends the ~50 MB extension budget).
    public let maxFrameSize: Int

    /// Set once an oversized frame, runaway buffer, or corrupt/unknown frame is seen;
    /// the caller must drop the connection.
    public private(set) var shouldDisconnect = false

    public init(maxFrameSize: Int = 1 << 20) {
        self.maxFrameSize = maxFrameSize
    }

    public func append(_ data: Data) {
        buffer.append(data)
        // Even before a length field is parsed, never let the backlog grow without bound.
        if buffer.count - cursor > maxFrameSize + (1 << 16) {
            shouldDisconnect = true
        }
    }

    /// Returns the next complete frame, or nil if more bytes are needed (or the stream is bad).
    public func next() -> WebSocketFrame? {
        if shouldDisconnect { return nil }

        let base = buffer.startIndex
        func byte(_ i: Int) -> UInt8 { buffer[base + cursor + i] }
        func available() -> Int { buffer.count - cursor }

        guard available() >= 2 else { compact(); return nil }

        let b0 = byte(0)
        let b1 = byte(1)

        let fin = (b0 & 0x80) != 0
        guard let opcode = WebSocketOpcode(rawValue: b0 & 0x0F) else {
            // Unknown opcode means the stream is corrupt/desynced. Don't try to resync
            // (byte-skipping could recurse a million deep on a hostile stream) — drop it.
            shouldDisconnect = true
            return nil
        }
        let masked = (b1 & 0x80) != 0
        var payloadLength = Int(b1 & 0x7F)
        var offset = 2

        if payloadLength == 126 {
            guard available() >= 4 else { compact(); return nil }
            payloadLength = (Int(byte(2)) << 8) | Int(byte(3))
            offset = 4
        } else if payloadLength == 127 {
            guard available() >= 10 else { compact(); return nil }
            var len = 0
            for i in 2..<10 {
                // Reject anything that would overflow Int or exceed the cap before allocating.
                if len > (Int.max >> 8) { shouldDisconnect = true; return nil }
                len = (len << 8) | Int(byte(i))
            }
            payloadLength = len
            offset = 10
        }

        guard payloadLength >= 0, payloadLength <= maxFrameSize else {
            shouldDisconnect = true
            return nil
        }

        if masked { offset += 4 }
        guard available() >= offset + payloadLength else { compact(); return nil }

        let maskStart = masked ? offset - 4 : offset
        let payloadStart = base + cursor + offset
        var payload = buffer.subdata(in: payloadStart..<payloadStart + payloadLength)
        if masked {
            let m0 = byte(maskStart), m1 = byte(maskStart + 1)
            let m2 = byte(maskStart + 2), m3 = byte(maskStart + 3)
            let mask = [m0, m1, m2, m3]
            for i in 0..<payload.count {
                payload[payload.startIndex + i] ^= mask[i % 4]
            }
        }

        cursor += offset + payloadLength
        return WebSocketFrame(fin: fin, opcode: opcode, payload: payload)
    }

    /// Reclaims consumed bytes once the cursor has advanced far enough to be worth it.
    private func compact() {
        guard cursor > 0 else { return }
        if cursor >= buffer.count {
            buffer.removeAll(keepingCapacity: true)
            cursor = 0
        } else if cursor > (1 << 16) {
            buffer = buffer.subdata(in: (buffer.startIndex + cursor)..<buffer.endIndex)
            cursor = 0
        }
    }
}
