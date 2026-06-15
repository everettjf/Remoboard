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
public final class WebSocketDecoder {
    private var buffer = Data()

    public init() {}

    public func append(_ data: Data) {
        buffer.append(data)
    }

    /// Returns the next complete frame, or nil if more bytes are needed.
    public func next() -> WebSocketFrame? {
        guard buffer.count >= 2 else { return nil }

        let bytes = [UInt8](buffer)
        let b0 = bytes[0]
        let b1 = bytes[1]

        let fin = (b0 & 0x80) != 0
        guard let opcode = WebSocketOpcode(rawValue: b0 & 0x0F) else {
            // Unknown opcode — drop one byte and resync.
            buffer.removeFirst(1)
            return next()
        }
        let masked = (b1 & 0x80) != 0
        var payloadLength = Int(b1 & 0x7F)
        var offset = 2

        if payloadLength == 126 {
            guard bytes.count >= 4 else { return nil }
            payloadLength = (Int(bytes[2]) << 8) | Int(bytes[3])
            offset = 4
        } else if payloadLength == 127 {
            guard bytes.count >= 10 else { return nil }
            var len = 0
            for i in 2..<10 { len = (len << 8) | Int(bytes[i]) }
            payloadLength = len
            offset = 10
        }

        var maskKey: [UInt8] = []
        if masked {
            guard bytes.count >= offset + 4 else { return nil }
            maskKey = Array(bytes[offset..<offset + 4])
            offset += 4
        }

        guard bytes.count >= offset + payloadLength else { return nil }

        var payload = [UInt8](bytes[offset..<offset + payloadLength])
        if masked {
            for i in 0..<payload.count {
                payload[i] ^= maskKey[i % 4]
            }
        }

        buffer.removeFirst(offset + payloadLength)
        return WebSocketFrame(fin: fin, opcode: opcode, payload: Data(payload))
    }
}
