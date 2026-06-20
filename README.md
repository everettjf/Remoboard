# Remoboard (Swift)

[![npm: remoboard](https://img.shields.io/npm/v/remoboard?label=npm%20remoboard&color=cb3837)](https://www.npmjs.com/package/remoboard)
[![npm: remoboard-mcp](https://img.shields.io/npm/v/remoboard-mcp?label=npm%20remoboard-mcp&color=cb3837)](https://www.npmjs.com/package/remoboard-mcp)
[![PyPI: remoboard](https://img.shields.io/pypi/v/remoboard?label=PyPI%20remoboard&color=3776ab)](https://pypi.org/project/remoboard/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

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
- **PIN pairing.** The keyboard shows a 6-digit PIN (stable for the session); a client must
  send it before any input is honored, and the server drops a connection after 5 wrong
  attempts, so a random person on the same Wi-Fi can't type into your phone.
- **Rebuilt web UI** (Svelte, single offline file): proper CJK/IME handling via
  composition events, live mirror of the phone's text field, robust exponential-backoff
  reconnect + heartbeat, quick-word management, clipboard, send history, light/dark
  (follows the system) and a responsive, mobile-friendly layout.
- **Localized into 10 languages** (English, 简体中文, 日本語, 한국어, Deutsch, Français,
  Español, Português, Русский, Italiano) across the web UI, host app, and keyboard.
- **SwiftUI host app** and a **Swift/UIKit keyboard extension**.
- **Remote clipboard** — push text to / pull text from the phone's system clipboard
  from the browser.
- **Handoff** — hand the connection URL to the host app, which publishes an Apple
  Continuity activity so you can resume on your Mac via Handoff.
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
    SiteResources.swift  Loads the bundled web UI
  Resources/site/      Built web UI (index.html, favicon.ico)
keyboard/            RemoKeyboard extension (UIKit)
remoboard/           Host app (SwiftUI)
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

## Protocol (v1)

Client → phone: `{"v":1,"t":"hello","pin":"482103"}`, `{"t":"input","text":"…","seq":7}`,
`{"t":"delete","seq":8}`, `{"t":"move","dir":"left","seq":9}`,
`{"t":"clip-set","text":"…"}`, `{"t":"clip-get"}`, `{"t":"handoff","text":"…"}`, `{"t":"ping"}`.

Phone → client: `{"t":"paired"}`, `{"t":"deny","reason":"pin"}`,
`{"t":"context","before":"…","after":"…"}`, `{"t":"quickwords","items":[…]}`,
`{"t":"clip","text":"…"}`, `{"t":"info","message":"…"}`, `{"t":"pong"}`.

## Developer packages

Client libraries that drive the keyboard from code (see [`packages/`](packages)). All
published and speak the same WebSocket protocol:

| Package | Install | Docs |
| --- | --- | --- |
| [`remoboard`](https://www.npmjs.com/package/remoboard) (Node.js) | `npm install remoboard` | [packages/node](packages/node) |
| [`remoboard`](https://pypi.org/project/remoboard/) (Python) | `pip install remoboard` | [packages/python](packages/python) |
| [`remoboard-mcp`](https://www.npmjs.com/package/remoboard-mcp) (MCP server) | `npx -y remoboard-mcp` | [packages/mcp](packages/mcp) |

```js
// Node
import { RemoboardClient } from 'remoboard'
const rb = new RemoboardClient({ host: '192.168.1.20', pin: '482103' })
await rb.connect()
await rb.type('Hello 世界 👋')
await rb.enter()
```

```python
# Python
from remoboard import RemoboardSync
with RemoboardSync(host='192.168.1.20', pin='482103') as rb:
    rb.type('Hello 世界 👋')
    rb.enter()
```

The MCP server lets an AI assistant (Claude, …) type into your phone — add it with
`npx -y remoboard-mcp` and `REMOBOARD_HOST` / `REMOBOARD_PIN`; see
[packages/mcp](packages/mcp).

## License

MIT. See [LICENSE](LICENSE).
