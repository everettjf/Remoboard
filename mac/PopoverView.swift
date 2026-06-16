//
//  PopoverView.swift
//  Remoboard (macOS companion)
//

import SwiftUI
import AppKit

struct PopoverView: View {
    @ObservedObject var client: MacClient
    @ObservedObject var discovery: Discovery

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            Group {
                if client.phase == .paired {
                    typingView
                } else {
                    connectView
                }
            }
            .padding(12)
        }
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text(t("title")).font(.headline)
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch client.phase {
            case .paired: return (client.endpointLabel, .green)
            case .connecting: return (t("connecting"), .orange)
            case .pairing: return (t("pairing"), .orange)
            case .denied: return (t("denied"), .red)
            case .disconnected: return ("", .secondary)
            }
        }()
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Connect

    @State private var pin = ""
    @State private var manualHost = ""

    private var connectView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "number")
                TextField(t("pin"), text: $pin)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
            }

            Text(t("discover")).font(.caption).foregroundStyle(.secondary)
            if discovery.devices.isEmpty {
                Text(t("searching")).font(.caption2).foregroundStyle(.tertiary)
            } else {
                ForEach(discovery.devices) { device in
                    Button {
                        connectDiscovered(device)
                    } label: {
                        HStack {
                            Image(systemName: "iphone")
                            Text(device.name)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                    .disabled(pin.isEmpty)
                }
            }

            Divider()
            Text(t("manual")).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField(t("host"), text: $manualHost)
                    .textFieldStyle(.roundedBorder)
                Button(t("connect")) {
                    client.connect(host: manualHost, port: 7777, pin: pin)
                }
                .disabled(manualHost.isEmpty || pin.isEmpty)
            }

            if client.phase == .denied {
                Text(t("denied")).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func connectDiscovered(_ device: Discovery.Device) {
        discovery.resolve(device) { resolved in
            guard let (host, port) = resolved else { return }
            manualHost = host   // reflect the address so the user can re-pair if denied
            client.connect(host: host, port: port, pin: pin)
        }
    }

    // MARK: Typing

    @State private var buffer = ""
    @State private var clipSend = ""
    @State private var copied = false

    private var typingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Echo of the phone's field
            VStack(alignment: .leading, spacing: 2) {
                Text(t("onPhone")).font(.caption2).foregroundStyle(.secondary)
                Text(echoText)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))

            // Compose
            TextEditor(text: $buffer)
                .font(.body)
                .frame(height: 90)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15)))
                .onChange(of: buffer) { newValue in client.syncBuffer(newValue) }

            HStack {
                Text(t("hintKeys")).font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button(t("clearKeep")) {
                    buffer = ""
                    client.resetBufferMirror()
                }
                .font(.caption)
            }

            if !client.quickWords.isEmpty {
                Text(t("quickWords")).font(.caption2).foregroundStyle(.secondary)
                wrap(client.quickWords) { word in
                    Button(word) { client.sendQuickWord(word) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            Divider()

            // Clipboard
            Text(t("clipboard")).font(.caption2).foregroundStyle(.secondary)
            HStack {
                TextField(t("clipPlaceholder"), text: $clipSend)
                    .textFieldStyle(.roundedBorder)
                Button(t("pushClip")) {
                    client.setPhoneClipboard(clipSend)
                    clipSend = ""
                }
                .disabled(clipSend.isEmpty)
            }
            HStack {
                Button(t("pullClip")) { client.getPhoneClipboard() }
                Button(t("sendToApp")) { client.handoff(buffer) }
                    .disabled(buffer.isEmpty)
            }
            .controlSize(.small)

            if let clip = client.phoneClip {
                HStack {
                    Text(clip.isEmpty ? t("phoneClipEmpty") : clip)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    if !clip.isEmpty {
                        Button(copied ? t("copied") : t("copy")) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(clip, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        }
                        .controlSize(.small)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
            }

            Divider()
            HStack {
                Spacer()
                Button(t("disconnect"), role: .destructive) {
                    buffer = ""
                    client.disconnect()
                }
            }
        }
    }

    private var echoText: String {
        let before = client.contextBefore
        let after = client.contextAfter
        return before + "⌶" + after
    }

    // Simple flow layout for chips.
    @ViewBuilder
    private func wrap<Item: Hashable, Content: View>(_ items: [Item], @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        let columns = [GridItem(.adaptive(minimum: 70), spacing: 6)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}
