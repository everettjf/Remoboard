import SwiftUI
import RemoboardKit

struct ConnectionDiagnosticsView: View {
    @State private var events = Settings.shared.diagnosticEvents
    @State private var history = Settings.shared.clipboardHistory
    @State private var allowRead = Settings.shared.allowRemoteClipboardRead
    @State private var allowWrite = Settings.shared.allowRemoteClipboardWrite
    @State private var pasted = ""

    var body: some View {
        List {
            Section("Pairing Verification") {
                if let success = events.last(where: { $0.kind == "pairing" && $0.detail.contains("verified") }) {
                    Label("Verified \(success.date.formatted(date: .abbreviated, time: .standard))", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                } else { Label("No verified pairing recorded yet", systemImage: "shield.slash") }
                Text("A success record is written only after the browser's WebSocket PIN handshake completes.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Clipboard Privacy") {
                Toggle("Allow remote clipboard reads", isOn: $allowRead).onChange(of: allowRead) { Settings.shared.allowRemoteClipboardRead = $0 }
                Toggle("Allow remote clipboard writes", isOn: $allowWrite).onChange(of: allowWrite) { Settings.shared.allowRemoteClipboardWrite = $0 }
                if #available(iOS 16.0, *) {
                    PasteButton(payloadType: String.self) { values in pasted = values.first ?? ""; Settings.shared.rememberClipboard(pasted); reload() }.buttonBorderShape(.roundedRectangle)
                }
                if !pasted.isEmpty { Text(pasted).lineLimit(3).privacySensitive() }
                Button("Clear Clipboard History", role: .destructive) { Settings.shared.clearClipboardHistory(); reload() }.disabled(history.isEmpty)
                ForEach(Array(history.enumerated()), id: \.offset) { _, item in Text(item).lineLimit(2).privacySensitive() }
            }
            Section("Redacted Connection Log") {
                ForEach(events.reversed()) { event in VStack(alignment: .leading) { Text(event.kind.capitalized).font(.headline); Text(event.detail); Text(event.date.formatted()).font(.caption).foregroundStyle(.secondary) } }
                Button("Clear Diagnostics", role: .destructive) { Settings.shared.clearDiagnostics(); reload() }.disabled(events.isEmpty)
            }
        }
        .navigationTitle("Diagnostics")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { ShareLink(item: diagnosticText) { Image(systemName: "square.and.arrow.up") }.disabled(events.isEmpty) } }
        .onAppear(perform: reload)
    }

    private var diagnosticText: String { (["Remoboard diagnostics (payloads redacted)"] + events.map { "\($0.date.formatted(.iso8601)) [\($0.kind)] \($0.detail)" }).joined(separator: "\n") }
    private func reload() { events = Settings.shared.diagnosticEvents; history = Settings.shared.clipboardHistory }
}
