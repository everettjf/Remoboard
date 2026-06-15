//
//  Protocol.swift
//  RemoboardKit
//
//  Wire protocol shared between the browser, the keyboard extension and the host app.
//  Replaces the legacy "command##rkb-1l0v3y0u3000##content" separator format with
//  a small versioned JSON protocol carried over WebSocket text frames.
//

import Foundation

public enum RemoProtocol {
    /// Bumped when the wire format changes in a non-backward-compatible way.
    public static let version = 1
}

/// Cursor movement directions understood by the keyboard.
public enum MoveDirection: String {
    case left, right, up, down
}

/// Messages sent from the browser to the phone.
public enum InboundMessage {
    /// First frame on a fresh connection. Carries the pairing PIN.
    case hello(pin: String)
    /// Insert text at the cursor.
    case input(text: String, seq: Int?)
    /// Delete one character backwards.
    case delete(seq: Int?)
    /// Move the cursor.
    case move(dir: MoveDirection, seq: Int?)
    /// Heartbeat.
    case ping
    /// Anything we don't recognise (forward compatibility).
    case unknown(type: String)
}

/// Messages sent from the phone back to the browser.
public enum OutboundMessage {
    /// Pairing succeeded.
    case paired
    /// Pairing rejected. `reason` is a machine token ("pin", "locked", ...).
    case deny(reason: String)
    /// Live mirror of the focused text field on the phone.
    case context(before: String, after: String)
    /// The user's quick words, pushed so the browser can offer one-tap insert.
    case quickWords([String])
    /// Heartbeat reply.
    case pong
    /// Human readable status line.
    case info(message: String)
}

public enum WireCodec {

    public static func decode(_ data: Data) -> InboundMessage? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dict = object as? [String: Any]
        else { return nil }

        let type = dict["t"] as? String ?? ""
        let seq = (dict["seq"] as? NSNumber)?.intValue

        switch type {
        case "hello":
            return .hello(pin: dict["pin"] as? String ?? "")
        case "input":
            return .input(text: dict["text"] as? String ?? "", seq: seq)
        case "delete":
            return .delete(seq: seq)
        case "move":
            let dir = MoveDirection(rawValue: dict["dir"] as? String ?? "") ?? .left
            return .move(dir: dir, seq: seq)
        case "ping":
            return .ping
        default:
            return .unknown(type: type)
        }
    }

    public static func encode(_ message: OutboundMessage) -> Data {
        var dict: [String: Any] = ["v": RemoProtocol.version]
        switch message {
        case .paired:
            dict["t"] = "paired"
        case .deny(let reason):
            dict["t"] = "deny"
            dict["reason"] = reason
        case .context(let before, let after):
            dict["t"] = "context"
            dict["before"] = before
            dict["after"] = after
        case .quickWords(let items):
            dict["t"] = "quickwords"
            dict["items"] = items
        case .pong:
            dict["t"] = "pong"
        case .info(let message):
            dict["t"] = "info"
            dict["message"] = message
        }
        return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }
}
