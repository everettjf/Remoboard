# remoboard (Node.js)

Official Node.js client for [Remoboard](https://github.com/everettjf/Remoboard) — type
into a phone running the Remoboard keyboard, from code.

It connects to the WebSocket server the Remoboard keyboard extension hosts on the phone
and speaks the versioned JSON protocol (v1).

## Install

```bash
npm install remoboard
```

Requires Node 18+.

## Quick start

On the phone: switch to the Remoboard keyboard. It shows a URL like `http://192.168.1.20:7777`
and a **PIN**. Use that IP and PIN:

```js
import { RemoboardClient } from 'remoboard'

const rb = new RemoboardClient({ host: '192.168.1.20', pin: '482103' })

await rb.connect()            // resolves once the phone confirms pairing
await rb.type('Hello 世界 👋')  // appears on the phone instantly
await rb.enter()
await rb.type('second line')
rb.close()
```

## API

### `new RemoboardClient(options)`

| option        | type      | default | description                                  |
| ------------- | --------- | ------- | -------------------------------------------- |
| `host`        | string    | —       | Phone IP/hostname shown on the keyboard.     |
| `pin`         | string    | —       | Pairing PIN shown on the keyboard.           |
| `port`        | number    | `7777`  | Server port.                                 |
| `pairTimeout` | number    | `8000`  | ms to wait for the `paired` reply.           |
| `reconnect`   | boolean   | `false` | Auto-reconnect and re-pair on drop.          |

### Methods

- `connect(): Promise<this>` — open + pair. Rejects with `PairingError` on a wrong PIN.
- `type(text)` — insert text at the cursor (any Unicode; emoji/CJK safe).
- `enter()` — newline / submit.
- `backspace()` — delete one character back.
- `move('left'|'right'|'up'|'down')` — move the cursor.
- `setClipboard(text)` — write the phone's system clipboard.
- `getClipboard(): Promise<string>` — read the phone's clipboard.
- `setQuickWords(string[])` — replace the user's quick words.
- `handoff(text)` — hand text to the phone's host app.
- `ping()` / `close()`.

Input methods are chainable and synchronous (fire-and-forget over the socket); only
`connect()` and `getClipboard()` return promises.

### Events

`client.on(name, handler)`:

- `connected` — socket open (before pairing).
- `paired` — pairing confirmed.
- `context` — `{ before, after }`, a live mirror of the focused phone field.
- `quickwords` — `string[]`, the user's quick words.
- `clipboard` — `string`, the phone's clipboard (reply to `getClipboard` or a push).
- `info` — `string`, a human-readable status line.
- `close`, `error`.

## Notes

- The phone and your machine must be on the same network and able to reach each other.
- The server drops a connection after 5 wrong PINs.
- The protocol is also implemented by the [Python client](../python) and the
  [MCP server](../mcp).

## License

MIT.
