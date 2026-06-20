# Remoboard developer packages

Client libraries for driving the [Remoboard](https://github.com/everettjf/Remoboard)
remote keyboard from code. Each connects to the WebSocket server the Remoboard keyboard
extension hosts on the phone and speaks the same versioned JSON protocol (v1).

| Package | Language | Use it for |
| --- | --- | --- |
| [`node/`](node) — `remoboard` | Node.js (18+) | Scripts, bots, automation in JS/TS. |
| [`python/`](python) — `remoboard` | Python (3.9+) | Scripts, automation in Python (async or sync). |
| [`mcp/`](mcp) — `remoboard-mcp` | MCP server | Let an AI assistant (Claude, …) type into your phone. |

All three are thin clients over the same transport, so anything one can do, the others can
too: type, press control keys, move the cursor, and read/write the phone clipboard.

## How it works

1. On the phone, the Remoboard keyboard runs a tiny HTTP + WebSocket server on
   `http://<phone-ip>:7777` and shows a pairing **PIN**.
2. A client opens `ws://<phone-ip>:7777/ws`, sends `hello` with the PIN, and once the
   phone replies `paired` it can send input messages.
3. Text/keys are applied to whatever text field the phone keyboard is focused on.

The phone and the client must be on the same network and able to reach each other. The
server drops a connection after 5 wrong PINs.

## Protocol (v1)

WebSocket text frames carrying JSON. Every message has `"v": 1`.

**Client → phone**

| `t`         | fields                       | meaning                              |
| ----------- | ---------------------------- | ------------------------------------ |
| `hello`     | `pin`                        | first frame; pair with the PIN.      |
| `input`     | `text`, `seq`                | insert text at the cursor.           |
| `delete`    | `seq`                        | delete one character backwards.      |
| `move`      | `dir` (`left`/`right`/`up`/`down`), `seq` | move the cursor.        |
| `clip-set`  | `text`                       | write the phone clipboard.           |
| `clip-get`  | —                            | request the phone clipboard.         |
| `words-set` | `items` (string[])           | replace the user's quick words.      |
| `handoff`   | `text`                       | hand text to the phone's host app.   |
| `ping`      | —                            | liveness.                            |

**Phone → client**

| `t`          | fields            | meaning                                       |
| ------------ | ----------------- | --------------------------------------------- |
| `paired`     | —                 | pairing accepted.                             |
| `deny`       | `reason`          | pairing rejected (`"pin"`).                   |
| `context`    | `before`, `after` | live mirror of the focused field's text.      |
| `quickwords` | `items`           | the user's quick words.                       |
| `clip`       | `text`            | the phone clipboard (reply to `clip-get`).    |
| `info`       | `message`         | human-readable status line.                   |
| `pong`       | —                 | heartbeat reply.                              |

Input messages (`input`/`delete`/`move`/`clip-*`/`words-set`/`handoff`) are honored only
after pairing. `seq` is a monotonically increasing integer the client assigns so the phone
applies edits in order.

## License

MIT.
