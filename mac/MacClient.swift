//
//  MacClient.swift
//  Remoboard (macOS companion)
//
//  WebSocket client that speaks the same JSON protocol as the browser UI, letting you
//  type from the menu bar. Uses URLSessionWebSocketTask (client role needs no raw
//  sockets or hand-rolled framing).
//

import Foundation
import AppKit

@MainActor
final class MacClient: ObservableObject {

    enum Phase: Equatable {
        case disconnected, connecting, pairing, paired, denied
    }

    @Published var phase: Phase = .disconnected
    @Published var contextBefore = ""
    @Published var contextAfter = ""
    @Published var quickWords: [String] = []
    @Published var phoneClip: String?
    @Published var info = ""
    @Published var endpointLabel = ""

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var host = ""
    private var port = 7777
    private var pin = ""
    private var seq = 0
    private var lastSent = ""
    private var shouldReconnect = false
    private var backoff: TimeInterval = 1
    private var pingTimer: Timer?
    private var reconnectWork: DispatchWorkItem?

    // MARK: Connection

    func connect(host: String, port: Int, pin: String) {
        self.host = host
        self.port = port
        self.pin = pin
        self.endpointLabel = "\(host):\(port)"
        backoff = 1
        shouldReconnect = true
        openSocket()
    }

    func disconnect() {
        shouldReconnect = false
        reconnectWork?.cancel()
        stopPing()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        phase = .disconnected
        resetMirror()
    }

    private func openSocket() {
        guard let url = URL(string: "ws://\(host):\(port)/ws") else { return }
        phase = .connecting
        lastSent = ""
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        receiveLoop()
        // URLSessionWebSocketTask queues sends until the socket opens.
        sendRaw(["t": "hello", "pin": pin])
        phase = .pairing
        startPing()
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    Task { @MainActor in self?.handle(text) }
                }
                Task { @MainActor in self?.receiveLoop() }
            case .failure:
                Task { @MainActor in self?.handleDisconnect() }
            }
        }
    }

    private func handleDisconnect() {
        stopPing()
        task = nil
        resetMirror()
        guard shouldReconnect else {
            // A deny cancels the socket, which lands here — keep the .denied state (and its
            // re-pair UI) instead of clobbering it with .disconnected.
            if phase != .denied { phase = .disconnected }
            return
        }
        phase = .connecting
        let delay = backoff
        backoff = min(backoff * 2, 8)   // exponential backoff, matching the web client
        let work = DispatchWorkItem { [weak self] in self?.openSocket() }
        reconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: Inbound

    private func handle(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        switch obj["t"] as? String {
        case "paired":
            phase = .paired
            backoff = 1   // reset backoff after a healthy connection
        case "deny":
            // Stop auto-reconnecting (don't hammer with a bad PIN) but keep the endpoint so
            // the user can re-pair with a fresh PIN from the popover.
            phase = .denied
            shouldReconnect = false
            reconnectWork?.cancel()   // cancel any reconnect scheduled by an earlier drop
            reconnectWork = nil
            stopPing()
            task?.cancel(with: .goingAway, reason: nil)
            task = nil
        case "context":
            contextBefore = obj["before"] as? String ?? ""
            contextAfter = obj["after"] as? String ?? ""
        case "quickwords":
            quickWords = obj["items"] as? [String] ?? []
        case "clip":
            phoneClip = obj["text"] as? String ?? ""
        case "open":
            handleHandoff(obj["text"] as? String ?? "")
        case "info":
            info = obj["message"] as? String ?? ""
        default:
            break
        }
    }

    /// Handoff from the phone: open a URL in the default browser/app, otherwise copy it.
    private func handleHandoff(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let url = Self.openableURL(text) {
            NSWorkspace.shared.open(url)
            info = "Opened \(url.absoluteString)"
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            info = "Copied from phone"
        }
    }

    /// A URL we should actually open: an explicit scheme, or a bare domain we can https://.
    static func openableURL(_ text: String) -> URL? {
        guard !text.contains(" "), !text.contains("\n") else { return nil }
        if let u = URL(string: text), let scheme = u.scheme?.lowercased(), !scheme.isEmpty {
            // http/https need a host; custom schemes (mailto:, etc.) are fine as-is.
            if scheme == "http" || scheme == "https" { return u.host != nil ? u : nil }
            return u
        }
        if text.contains("."), let u = URL(string: "https://\(text)"), u.host != nil { return u }
        return nil
    }

    // MARK: Outbound

    private func nextSeq() -> Int { seq += 1; return seq }

    private func sendRaw(_ dict: [String: Any]) {
        var payload = dict
        payload["v"] = 1
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let string = String(data: data, encoding: .utf8)
        else { return }
        task?.send(.string(string)) { _ in }
    }

    /// Live-diff the editor buffer against what the phone already has and send the delta.
    func syncBuffer(_ newValue: String) {
        let old = Array(lastSent)
        let new = Array(newValue)
        var prefix = 0
        let minLen = min(old.count, new.count)
        while prefix < minLen && old[prefix] == new[prefix] { prefix += 1 }
        let deletions = old.count - prefix
        let insertion = String(new[prefix...])
        for _ in 0..<deletions { sendRaw(["t": "delete", "seq": nextSeq()]) }
        if !insertion.isEmpty { sendRaw(["t": "input", "text": insertion, "seq": nextSeq()]) }
        lastSent = newValue
    }

    /// Clears the local buffer mirror without deleting anything on the phone.
    func resetBufferMirror() { lastSent = "" }

    func sendQuickWord(_ word: String) {
        sendRaw(["t": "input", "text": word, "seq": nextSeq()])
    }

    func move(_ dir: String) {
        sendRaw(["t": "move", "dir": dir, "seq": nextSeq()])
    }

    func sendNewline() { sendRaw(["t": "input", "text": "\n", "seq": nextSeq()]) }
    func sendBackspace() { sendRaw(["t": "delete", "seq": nextSeq()]) }

    func getPhoneClipboard() { sendRaw(["t": "clip-get"]) }
    func setPhoneClipboard(_ text: String) { sendRaw(["t": "clip-set", "text": text]) }
    func handoff(_ text: String) { sendRaw(["t": "handoff", "text": text]) }

    // MARK: Helpers

    private func resetMirror() {
        contextBefore = ""
        contextAfter = ""
    }

    private func startPing() {
        stopPing()
        let timer = Timer(timeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sendRaw(["t": "ping"]) }
        }
        RunLoop.main.add(timer, forMode: .common)
        pingTimer = timer
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}
