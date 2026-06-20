# remoboard (Python)

Official Python client for [Remoboard](https://github.com/everettjf/Remoboard) — type
into a phone running the Remoboard keyboard, from code.

It connects to the WebSocket server the Remoboard keyboard extension hosts on the phone
and speaks the versioned JSON protocol (v1).

## Install

```bash
pip install remoboard
```

Requires Python 3.9+ (depends on `websockets`).

## Quick start

On the phone: switch to the Remoboard keyboard. It shows a URL like `http://192.168.1.20:7777`
and a **PIN**.

### Async

```python
import asyncio
from remoboard import RemoboardClient

async def main():
    async with RemoboardClient(host="192.168.1.20", pin="482103") as rb:
        await rb.type("Hello 世界 👋")
        await rb.enter()
        await rb.type("second line")
        print(await rb.get_clipboard())

asyncio.run(main())
```

### Sync (no asyncio)

```python
from remoboard import RemoboardSync

with RemoboardSync(host="192.168.1.20", pin="482103") as rb:
    rb.type("Hello 世界")
    rb.enter()
```

## API

### `RemoboardClient(host, pin, port=7777, pair_timeout=8.0, on_context=..., on_quickwords=..., on_clipboard=..., on_info=...)`

Async client; also an async context manager (`async with`).

- `await connect()` — open + pair. Raises `PairingError` on a wrong PIN.
- `await type(text)` — insert text at the cursor (any Unicode).
- `await enter()` / `await backspace()`
- `await move("left"|"right"|"up"|"down")`
- `await set_clipboard(text)` / `await get_clipboard() -> str`
- `await set_quick_words(list)` / `await handoff(text)` / `await ping()`
- `await close()`

The optional `on_*` callbacks fire from the receive loop:
`on_context(before, after)`, `on_quickwords(list)`, `on_clipboard(text)`, `on_info(text)`.

### `RemoboardSync(host, pin, port=7777, **kwargs)`

Blocking wrapper backed by a private event loop and a context manager (`with`). Same
methods without `await` (`get_clipboard()` returns the string directly).

## Notes

- The phone and your machine must be on the same network and able to reach each other.
- The server drops a connection after 5 wrong PINs.
- The protocol is also implemented by the [Node client](../node) and the
  [MCP server](../mcp).

## License

MIT.
