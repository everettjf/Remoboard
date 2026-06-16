//
//  RemoServer.swift
//  RemoboardKit
//
//  A tiny HTTP + WebSocket server built on raw POSIX sockets and a single poll()
//  event loop. Raw sockets are used deliberately: unlike Network.framework's
//  NWListener, they do not trigger the iOS local-network permission prompt, which
//  cannot be granted from inside a keyboard extension. This mirrors what the legacy
//  mongoose-based server did, but with no third-party code.
//
//  Responsibilities:
//    - serve the bundled single-page web UI over HTTP
//    - upgrade /ws connections to WebSocket
//    - enforce PIN pairing before honoring input
//    - decode inbound JSON messages and hand them to `onInbound`
//    - broadcast outbound messages (context echo, quick words) to paired clients
//

import Foundation
import Darwin

public final class RemoServer {

    // MARK: Configuration & callbacks

    public var pin: String = ""
    public var quickWordsProvider: (() -> [String])?
    public var onInbound: ((InboundMessage) -> Void)?
    public var onClientCountChanged: ((Int) -> Void)?

    private let port: UInt16
    private let htmlData: Data
    private let faviconData: Data?

    // MARK: State

    private final class Client {
        let fd: Int32
        var isWebSocket = false
        var paired = false
        var pinAttempts = 0
        var rawBuffer = Data()              // pre-upgrade HTTP bytes
        var outBuffer = Data()              // pending bytes to write
        var closeAfterFlush = false
        let decoder = WebSocketDecoder()
        var fragmentOpcode: WebSocketOpcode?
        var fragmentData = Data()
        init(fd: Int32) { self.fd = fd }
    }

    /// Caps that protect the keyboard extension's tight memory budget and the PIN.
    private let maxClients = 12
    private let maxPinAttempts = 5
    private let maxFragmentBytes = 1 << 20

    private var listenFD: Int32 = -1
    private var wakePipe: [Int32] = [-1, -1]
    private var thread: Thread?
    private var running = false
    private var loopExited = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var clients: [Int32: Client] = [:]

    public init(port: UInt16, html: Data, favicon: Data?) {
        self.port = port
        self.htmlData = html
        self.faviconData = favicon
    }

    deinit { stop() }

    // MARK: Lifecycle

    public func start() {
        stop()
        signal(SIGPIPE, SIG_IGN)

        guard openListenSocket(), openWakePipe() else {
            closeAll()
            return
        }

        running = true
        loopExited = DispatchSemaphore(value: 0)
        let t = Thread { [weak self] in self?.runLoop() }
        t.name = "rkb.server"
        t.stackSize = 512 * 1024
        thread = t
        t.start()
    }

    public func stop() {
        guard running else {
            closeAll()
            return
        }
        running = false
        wake()
        // Wait for the poll loop to actually exit before closing fds, so we never close a
        // descriptor the worker is mid-syscall on (which could be reused under us). The
        // worker re-checks `running` on every poll timeout tick, so this wait reliably
        // succeeds well within the window even if the wake byte is somehow missed.
        _ = loopExited.wait(timeout: .now() + 2.0)
        thread = nil
        closeAll()
    }

    // MARK: Outbound

    /// Thread-safe. Queues a message for every paired WebSocket client.
    public func broadcast(_ message: OutboundMessage) {
        let frame = WebSocketEncoder.text(String(decoding: WireCodec.encode(message), as: UTF8.self))
        lock.lock()
        for client in clients.values where client.isWebSocket && client.paired {
            client.outBuffer.append(frame)
        }
        lock.unlock()
        wake()
    }

    // MARK: Socket setup

    private func openListenSocket() -> Bool {
        // Dual-stack: an AF_INET6 socket with IPV6_V6ONLY off also accepts IPv4 (v4-mapped),
        // so the companion can reach the phone over either family.
        let fd = socket(AF_INET6, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }

        var yes: Int32 = 1
        var no: Int32 = 0
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &no, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in6()
        addr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_addr = in6addr_any
        addr.sin6_port = port.bigEndian

        let bindResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }
        guard bindResult == 0, listen(fd, 64) == 0 else {
            close(fd)
            return false
        }
        setNonBlocking(fd)
        listenFD = fd
        return true
    }

    private func openWakePipe() -> Bool {
        var fds: [Int32] = [-1, -1]
        guard pipe(&fds) == 0 else { return false }
        setNonBlocking(fds[0])
        setNonBlocking(fds[1])
        wakePipe = fds
        return true
    }

    private func setNonBlocking(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    }

    private func wake() {
        guard wakePipe[1] >= 0 else { return }
        var byte: UInt8 = 1
        _ = write(wakePipe[1], &byte, 1)
    }

    private func closeAll() {
        lock.lock()
        for client in clients.values { close(client.fd) }
        clients.removeAll()
        lock.unlock()
        if listenFD >= 0 { close(listenFD); listenFD = -1 }
        if wakePipe[0] >= 0 { close(wakePipe[0]); wakePipe[0] = -1 }
        if wakePipe[1] >= 0 { close(wakePipe[1]); wakePipe[1] = -1 }
    }

    // MARK: Event loop

    private func runLoop() {
        while running {
            var pfds: [pollfd] = []
            pfds.append(pollfd(fd: listenFD, events: Int16(POLLIN), revents: 0))
            pfds.append(pollfd(fd: wakePipe[0], events: Int16(POLLIN), revents: 0))

            lock.lock()
            let snapshot = Array(clients.values)
            for client in snapshot {
                var events = Int32(POLLIN)
                if !client.outBuffer.isEmpty { events |= Int32(POLLOUT) }
                pfds.append(pollfd(fd: client.fd, events: Int16(truncatingIfNeeded: events), revents: 0))
            }
            lock.unlock()

            // Events (I/O, accept, broadcast, stop) wake poll immediately via an fd. The 1s
            // timeout is only a safety net so the worker always re-checks `running` and exits
            // even if a wake is ever missed — it is not a busy-tick.
            let n = poll(&pfds, nfds_t(pfds.count), 1000)
            if n < 0 {
                if errno == EINTR { continue }
                break
            }
            if !running { break }

            for pfd in pfds {
                guard pfd.revents != 0 else { continue }
                if pfd.fd == listenFD {
                    acceptConnections()
                } else if pfd.fd == wakePipe[0] {
                    drainWakePipe()
                } else {
                    let revents = Int32(pfd.revents)
                    if revents & (POLLHUP | POLLERR | POLLNVAL) != 0 {
                        removeClient(pfd.fd)
                        continue
                    }
                    if revents & POLLIN != 0 { handleReadable(pfd.fd) }
                    if revents & POLLOUT != 0 { handleWritable(pfd.fd) }
                }
            }
        }
        // stop() waits on this then closes fds. If we instead exited on a poll error
        // (running still true), own the teardown ourselves.
        let stoppedByRequest = !running
        running = false
        loopExited.signal()
        if !stoppedByRequest { closeAll() }
    }

    private func drainWakePipe() {
        var scratch = [UInt8](repeating: 0, count: 64)
        while read(wakePipe[0], &scratch, scratch.count) > 0 {}
    }

    private func acceptConnections() {
        while true {
            let fd = accept(listenFD, nil, nil)
            if fd < 0 { break }
            var yes: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
            setNonBlocking(fd)
            lock.lock()
            let full = clients.count >= maxClients
            if !full { clients[fd] = Client(fd: fd) }
            lock.unlock()
            if full {
                // Bound memory: refuse beyond the cap instead of letting a peer open fds at will.
                close(fd)
            } else {
                notifyCount()
            }
        }
    }

    private func client(for fd: Int32) -> Client? {
        lock.lock(); defer { lock.unlock() }
        return clients[fd]
    }

    private func removeClient(_ fd: Int32) {
        lock.lock()
        let existed = clients.removeValue(forKey: fd) != nil
        lock.unlock()
        if existed {
            close(fd)
            notifyCount()
        }
    }

    private func notifyCount() {
        let pairedCount: Int = {
            lock.lock(); defer { lock.unlock() }
            return clients.values.filter { $0.paired }.count
        }()
        DispatchQueue.main.async { [weak self] in
            self?.onClientCountChanged?(pairedCount)
        }
    }

    // MARK: Read / write

    private func handleReadable(_ fd: Int32) {
        guard let client = client(for: fd) else { return }

        var chunk = [UInt8](repeating: 0, count: 16 * 1024)
        var received = Data()
        while true {
            let n = read(fd, &chunk, chunk.count)
            if n > 0 {
                received.append(contentsOf: chunk[0..<n])
            } else if n == 0 {
                removeClient(fd)
                return
            } else {
                if errno == EAGAIN || errno == EWOULDBLOCK { break }
                removeClient(fd)
                return
            }
        }
        guard !received.isEmpty else { return }

        if client.isWebSocket {
            client.decoder.append(received)
            processFrames(client)
        } else {
            client.rawBuffer.append(received)
            processHandshake(client)
        }
    }

    private func handleWritable(_ fd: Int32) {
        lock.lock()
        guard let client = clients[fd] else { lock.unlock(); return }
        guard !client.outBuffer.isEmpty else { lock.unlock(); return }
        let data = client.outBuffer
        lock.unlock()

        let written = data.withUnsafeBytes { raw -> Int in
            guard let base = raw.baseAddress else { return 0 }
            return write(fd, base, data.count)
        }

        if written < 0 {
            if errno == EAGAIN || errno == EWOULDBLOCK { return }
            removeClient(fd)
            return
        }

        lock.lock()
        if let c = clients[fd] {
            c.outBuffer.removeFirst(min(written, c.outBuffer.count))
            let drained = c.outBuffer.isEmpty
            let shouldClose = c.closeAfterFlush
            lock.unlock()
            if drained && shouldClose { removeClient(fd) }
        } else {
            lock.unlock()
        }
    }

    private func enqueue(_ data: Data, to client: Client, closeAfter: Bool = false) {
        lock.lock()
        client.outBuffer.append(data)
        if closeAfter { client.closeAfterFlush = true }
        lock.unlock()
    }

    // MARK: HTTP handshake / static serving

    private func processHandshake(_ client: Client) {
        guard let headerRange = client.rawBuffer.range(of: Data("\r\n\r\n".utf8)) else {
            if client.rawBuffer.count > 64 * 1024 { removeClient(client.fd) }
            return
        }
        let headerData = client.rawBuffer.subdata(in: client.rawBuffer.startIndex..<headerRange.lowerBound)
        let leftover = client.rawBuffer.subdata(in: headerRange.upperBound..<client.rawBuffer.endIndex)
        client.rawBuffer = Data()

        guard let header = String(data: headerData, encoding: .utf8) else {
            removeClient(client.fd)
            return
        }

        let lines = header.components(separatedBy: "\r\n")
        let requestLine = lines.first ?? ""
        let parts = requestLine.components(separatedBy: " ")
        let path = parts.count >= 2 ? parts[1] : "/"

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let isUpgrade = (headers["upgrade"]?.lowercased().contains("websocket") ?? false)
        if isUpgrade, let key = headers["sec-websocket-key"] {
            enqueue(WebSocketHandshake.response(forKey: key), to: client)
            client.isWebSocket = true
            if !leftover.isEmpty {
                client.decoder.append(leftover)
                processFrames(client)
            }
        } else {
            serveStatic(path: path, to: client)
        }
    }

    private func serveStatic(path: String, to client: Client) {
        let route = path.components(separatedBy: "?").first ?? path
        switch route {
        case "/", "/index.html":
            enqueue(httpResponse(status: "200 OK", contentType: "text/html; charset=utf-8", body: htmlData),
                    to: client, closeAfter: true)
        case "/favicon.ico":
            if let favicon = faviconData {
                enqueue(httpResponse(status: "200 OK", contentType: "image/x-icon", body: favicon),
                        to: client, closeAfter: true)
            } else {
                enqueue(httpResponse(status: "404 Not Found", contentType: "text/plain", body: Data()),
                        to: client, closeAfter: true)
            }
        default:
            enqueue(httpResponse(status: "404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8)),
                    to: client, closeAfter: true)
        }
    }

    private func httpResponse(status: String, contentType: String, body: Data) -> Data {
        var head = "HTTP/1.1 \(status)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Cache-Control: no-store\r\n"
        head += "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(body)
        return data
    }

    // MARK: WebSocket frames

    private func processFrames(_ client: Client) {
        while let frame = client.decoder.next() {
            switch frame.opcode {
            case .ping:
                enqueue(WebSocketEncoder.pong(frame.payload), to: client)
            case .pong:
                break
            case .close:
                enqueue(WebSocketEncoder.close(), to: client, closeAfter: true)
            case .text, .binary:
                if frame.fin {
                    handleMessage(frame.payload, from: client)
                } else {
                    client.fragmentOpcode = frame.opcode
                    client.fragmentData = frame.payload
                }
            case .continuation:
                // A continuation with no started message is a protocol violation — drop it.
                guard client.fragmentOpcode != nil else {
                    enqueue(WebSocketEncoder.close(), to: client, closeAfter: true)
                    return
                }
                client.fragmentData.append(frame.payload)
                if client.fragmentData.count > maxFragmentBytes {
                    enqueue(WebSocketEncoder.close(), to: client, closeAfter: true)
                    return
                }
                if frame.fin {
                    let data = client.fragmentData
                    client.fragmentOpcode = nil
                    client.fragmentData = Data()
                    handleMessage(data, from: client)
                }
            }
        }
        // Oversized/hostile frame seen by the decoder — sever the connection.
        if client.decoder.shouldDisconnect {
            removeClient(client.fd)
        }
    }

    private func handleMessage(_ data: Data, from client: Client) {
        guard let message = WireCodec.decode(data) else { return }

        switch message {
        case .hello(let candidate):
            if client.paired { return }
            if !pin.isEmpty && candidate == pin {
                client.paired = true
                client.pinAttempts = 0
                send(.paired, to: client)
                if let words = quickWordsProvider?() {
                    send(.quickWords(words), to: client)
                }
                notifyCount()
            } else {
                client.pinAttempts += 1
                send(.deny(reason: "pin"), to: client)
                // Throttle brute force: drop the connection after a few wrong PINs so an
                // attacker can't sweep the keyspace on one socket.
                if client.pinAttempts >= maxPinAttempts {
                    enqueue(WebSocketEncoder.close(), to: client, closeAfter: true)
                }
            }
        case .ping:
            send(.pong, to: client)
        case .input, .delete, .move, .clipboardSet, .clipboardGet, .handoff:
            guard client.paired else {
                send(.deny(reason: "pin"), to: client)
                return
            }
            if let onInbound {
                DispatchQueue.main.async { onInbound(message) }
            }
        case .unknown:
            break
        }
    }

    private func send(_ message: OutboundMessage, to client: Client) {
        let json = String(decoding: WireCodec.encode(message), as: UTF8.self)
        enqueue(WebSocketEncoder.text(json), to: client)
    }
}
