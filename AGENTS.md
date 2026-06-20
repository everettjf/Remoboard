# Repository Guidelines

Remoboard is a Swift iOS host app + keyboard extension that relays text typed in a
desktop browser to the phone. The legacy Objective-C/C++ implementation is archived
under `ObjcVersion/` and is not built.

## Project Structure

- `RemoboardKit/` — shared framework. `Sources/` holds the JSON protocol, app-group
  settings, IPv4 enumeration, the RFC 6455 WebSocket codec, and the POSIX-socket
  HTTP/WebSocket server (`RemoServer.swift`). `Resources/site/` holds the built web UI.
- `keyboard/` — `RemoKeyboard` extension (UIKit). Hosts the server, injects text via
  `UITextDocumentProxy`.
- `remoboard/` — host app (SwiftUI): onboarding, quick-word management, test input,
  handoff (publishes an Apple Continuity activity from the connection URL).
- `web/` — Svelte source for the browser UI; `npm run deploy` builds a single offline
  `index.html` into `RemoboardKit/Resources/site/`.
- `project.yml` — XcodeGen definition. `Remoboard.xcodeproj` is generated from `project.yml` and committed; regenerate with `xcodegen generate`.

## Build & Run

- `xcodegen generate` after any change to `project.yml`, target file membership, or
  Info.plist/entitlements.
- `cd web && npm run deploy` after any change under `web/`; commit the regenerated
  `RemoboardKit/Resources/site/index.html`.
- Compile check (iOS): `xcodebuild -project Remoboard.xcodeproj -scheme Remoboard -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
- Real-device run is required to actually use the keyboard (extensions are limited in
  the simulator) and needs Full Access enabled.

## Conventions

- Minimum iOS 15. Use `NavigationView` (not `NavigationStack`, which is iOS 16+).
- Keep the keyboard extension lean — it runs under a tight (~50 MB) memory budget. Do not
  introduce heavy dependencies there.
- Use raw POSIX sockets for the server, **not** `Network.framework`/`NWListener`, which
  triggers the iOS local-network permission prompt that can't be granted in an extension.
- Shared state goes through `Settings` (App Group `group.everettjf.remoboard`).
- Wire protocol changes go in `RemoboardKit/Sources/Protocol.swift` and the web client
  (`web/src/`) together; bump `RemoProtocol.version` for breaking changes.
- Add new user-facing strings to all 10 `.lproj` (en, zh-Hans, ja, ko, de, fr, es,
  pt-BR, ru, it) and to `web/src/i18n.js`.

## Testing

No automated tests. The server core can be exercised on macOS by compiling the Foundation
-only sources (`Protocol.swift`, `WebSocket.swift`, `RemoServer.swift`) into a command-line
binary and driving it with a WebSocket client. Otherwise verify manually on device: PIN
pairing, live typing (including CJK/IME), cursor moves, quick words, and reconnect.
