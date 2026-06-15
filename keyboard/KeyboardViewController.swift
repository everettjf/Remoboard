//
//  KeyboardViewController.swift
//  RemoKeyboard
//
//  The keyboard extension. Hosts the HTTP/WebSocket relay server and applies the
//  text operations it receives to the focused text field via UITextDocumentProxy.
//

import UIKit
import RemoboardKit

final class KeyboardViewController: UIInputViewController {

    private let server = RemoServer.make(port: 7777)

    private let statusLabel = UILabel()
    private let urlLabel = UILabel()
    private let pinLabel = UILabel()
    private let nextKeyboardButton = UIButton(type: .system)
    private let wordsButton = UIButton(type: .system)
    private let returnButton = UIButton(type: .system)
    private let wordsTable = UITableView()

    private var quickWords: [String] = []
    private var contextThrottle = Throttle(interval: 0.08)
    private var serverRunning = false

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        quickWords = Settings.shared.quickWords
        buildUI()
        wireServer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard hasFullAccess else {
            showFullAccessGuide()
            return
        }
        startServerIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        server.stop()
        serverRunning = false
    }

    // MARK: Server

    private func wireServer() {
        server.onInbound = { [weak self] message in
            self?.apply(message)
        }
        server.quickWordsProvider = { Settings.shared.quickWords }
        server.onClientCountChanged = { [weak self] count in
            self?.updateStatus(connectedCount: count)
        }
    }

    private func startServerIfNeeded() {
        guard !serverRunning else { return }
        let pin = Self.makePIN()
        server.pin = pin
        server.start()
        serverRunning = true
        pinLabel.text = "PIN  \(pin)"
        updateURLs()
        updateStatus(connectedCount: 0)
    }

    private func updateURLs() {
        if let primary = LocalAddresses.primaryIPv4() {
            urlLabel.text = "http://\(primary.ip):7777"
        } else {
            urlLabel.text = NSLocalizedString("WifiNotFound", comment: "")
        }
    }

    private func updateStatus(connectedCount count: Int) {
        let key = count > 0 ? "StatusConnected" : "StatusWaiting"
        statusLabel.text = NSLocalizedString(key, comment: "")
    }

    // MARK: Applying remote operations

    private func apply(_ message: InboundMessage) {
        switch message {
        case .input(let text, _):
            textDocumentProxy.insertText(text)
        case .delete:
            textDocumentProxy.deleteBackward()
        case .move(let dir, _):
            switch dir {
            case .left: textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
            case .right: textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
            case .up: textDocumentProxy.adjustTextPosition(byCharacterOffset: -20)
            case .down: textDocumentProxy.adjustTextPosition(byCharacterOffset: 20)
            }
        case .hello, .ping, .unknown:
            break
        }
        broadcastContext()
    }

    private func broadcastContext() {
        contextThrottle.run { [weak self] in
            guard let self else { return }
            let before = self.textDocumentProxy.documentContextBeforeInput ?? ""
            let after = self.textDocumentProxy.documentContextAfterInput ?? ""
            self.server.broadcast(.context(before: before, after: after))
        }
    }

    // MARK: Full access

    private func showFullAccessGuide() {
        statusLabel.text = NSLocalizedString("GuideAllowFullAccess", comment: "")
        urlLabel.text = ""
        pinLabel.text = ""
    }

    // MARK: PIN

    private static func makePIN() -> String {
        String(format: "%04d", Int.random(in: 0...9999))
    }
}

// MARK: - UITableView

extension KeyboardViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        quickWords.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "word") ?? UITableViewCell(style: .default, reuseIdentifier: "word")
        cell.textLabel?.text = quickWords[indexPath.row]
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        textDocumentProxy.insertText(quickWords[indexPath.row])
        broadcastContext()
    }
}

// MARK: - UI construction

private extension KeyboardViewController {

    func buildUI() {
        view.backgroundColor = .clear

        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.text = NSLocalizedString("StatusWaiting", comment: "")

        urlLabel.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
        urlLabel.textAlignment = .center
        urlLabel.adjustsFontSizeToFitWidth = true

        pinLabel.font = .monospacedSystemFont(ofSize: 17, weight: .bold)
        pinLabel.textAlignment = .center

        let infoStack = UIStackView(arrangedSubviews: [statusLabel, urlLabel, pinLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.alignment = .fill

        configureBarButton(nextKeyboardButton, title: NSLocalizedString("Next", comment: ""))
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        configureBarButton(wordsButton, title: NSLocalizedString("Words", comment: ""))
        wordsButton.addTarget(self, action: #selector(toggleWords), for: .touchUpInside)

        configureBarButton(returnButton, title: NSLocalizedString("Return", comment: ""))
        returnButton.addTarget(self, action: #selector(tapReturn), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [nextKeyboardButton, wordsButton, returnButton])
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 6

        wordsTable.dataSource = self
        wordsTable.delegate = self
        wordsTable.backgroundColor = .clear
        wordsTable.isHidden = true
        wordsTable.rowHeight = 40

        let root = UIStackView(arrangedSubviews: [infoStack, wordsTable, buttonStack])
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            wordsTable.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            buttonStack.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    func configureBarButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.backgroundColor = UIColor(white: 1, alpha: 0.12)
        button.layer.cornerRadius = 6
    }

    @objc func toggleWords() {
        quickWords = Settings.shared.quickWords
        wordsTable.reloadData()
        wordsTable.isHidden.toggle()
    }

    @objc func tapReturn() {
        textDocumentProxy.insertText("\n")
        broadcastContext()
    }
}

/// Coalesces rapid calls so we don't flood the socket with context echoes.
final class Throttle {
    private let interval: TimeInterval
    private var lastFire: Date = .distantPast
    init(interval: TimeInterval) { self.interval = interval }
    func run(_ block: () -> Void) {
        let now = Date()
        guard now.timeIntervalSince(lastFire) >= interval else { return }
        lastFire = now
        block()
    }
}
