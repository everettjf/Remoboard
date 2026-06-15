# Remoboard (Swift)

Remoboard (远程输入法) lets you type in your computer's browser and have the text
appear instantly on your phone, inside whatever app you're using. The phone runs a
custom keyboard extension that hosts a tiny web server; you open the URL it shows,
enter a pairing PIN, and start typing.

This is a ground-up Swift rewrite of the original Objective-C/C++ app. The legacy
sources are preserved under [`ObjcVersion/`](ObjcVersion/) for reference.

## What changed from the Objective-C version

- **No C++ / Boost / mongoose.** The HTTP + WebSocket relay is ~600 lines of Swift
  built on raw POSIX sockets and a single `poll()` loop (`RemoboardKit/Sources/RemoServer.swift`).
  Raw sockets are used deliberately — `Network.framework`'s `NWListener` triggers the
  iOS local-network permission prompt, which can't be granted from a keyboard extension.
  This deletes the entire vendored `boost_1_70_0` tree (~63k files).
- **Versioned JSON protocol** over WebSocket, replacing the `command##rkb-…##content`
  string separator. See `RemoboardKit/Sources/Protocol.swift`.
- **PIN pairing.** The keyboard shows a 4-digit PIN; the browser must send it before any
  input is honored, so a random person on the same Wi-Fi can't type into your phone.
- **Rebuilt web UI** (Svelte, single offline file): proper CJK/IME handling via
  composition events, live mirror of the phone's text field, robust exponential-backoff
  reconnect + heartbeat, quick-word chips, dark mode, responsive layout.
- **SwiftUI host app** and a **Swift/UIKit keyboard extension**.
- **Remote clipboard** — push text to / pull text from the phone's system clipboard
  from any client (browser or Mac).
- **Handoff to the app** — send the current text into the Remoboard host app (via the
  `remoboard://` URL scheme) to copy, share, or keep it.
- **macOS menu-bar companion** (`mac/`) — discovers phones via Bonjour
  (`_remoboard._tcp`), pairs with the PIN, and lets you type, manage the clipboard, and
  hand off from the menu bar. The host app advertises the Bonjour service.
- Bluetooth / legacy IP modes dropped.

## Layout

```
RemoboardKit/        Shared framework (app + extension)
  Sources/
    Protocol.swift       JSON wire protocol + codec
    Settings.swift       App-group settings (quick words, etc.)
    LocalAddresses.swift IPv4 interface enumeration
    WebSocket.swift      RFC 6455 handshake + frame codec
    RemoServer.swift     POSIX-socket HTTP/WebSocket server + pairing
    BonjourAdvertiser.swift  Publishes _remoboard._tcp for companion discovery
    SiteResources.swift  Loads the bundled web UI
  Resources/site/      Built web UI (index.html, favicon.ico)
keyboard/            RemoKeyboard extension (UIKit)
remoboard/           Host app (SwiftUI)
mac/                 macOS menu-bar companion (SwiftUI)
web/                 Svelte source for the browser UI
project.yml          XcodeGen project definition
ObjcVersion/         Original Objective-C/C++ app (archived)
```

## Building

Prerequisites: Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`), Node 18+ (only to rebuild the web UI).

```bash
# 1. (only if you changed web/) rebuild the browser UI into the framework bundle
cd web && npm install && npm run deploy && cd ..

# 2. generate the Xcode project from project.yml
xcodegen generate

# 3. open and run on a real device (keyboard extensions are limited in the simulator)
open Remoboard.xcworkspace 2>/dev/null || open Remoboard.xcodeproj
```

Command-line build check (simulator, no signing):

```bash
xcodebuild -project Remoboard.xcodeproj -scheme Remoboard \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

On device: enable Remoboard in **Settings → General → Keyboard → Keyboards**, turn on
**Allow Full Access**, switch to the Remoboard keyboard, then open the shown
`http://<phone-ip>:7777` URL on your computer and enter the PIN.

### macOS companion

The `RemoboardMac` scheme builds the menu-bar app. Run it, open the **Remoboard** app on
your phone once so it advertises over Bonjour, pick the device (or enter its IP), type the
PIN, and type from the menu bar.

```bash
xcodebuild -project Remoboard.xcodeproj -scheme RemoboardMac \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## Protocol (v1)

Client → phone: `{"v":1,"t":"hello","pin":"4821"}`, `{"t":"input","text":"…","seq":7}`,
`{"t":"delete","seq":8}`, `{"t":"move","dir":"left","seq":9}`,
`{"t":"clip-set","text":"…"}`, `{"t":"clip-get"}`, `{"t":"handoff","text":"…"}`, `{"t":"ping"}`.

Phone → client: `{"t":"paired"}`, `{"t":"deny","reason":"pin"}`,
`{"t":"context","before":"…","after":"…"}`, `{"t":"quickwords","items":[…]}`,
`{"t":"clip","text":"…"}`, `{"t":"info","message":"…"}`, `{"t":"pong"}`.

## License

MIT. See [LICENSE](LICENSE).
