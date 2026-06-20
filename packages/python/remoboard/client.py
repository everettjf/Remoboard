"""Remoboard WebSocket client (async + sync)."""

from __future__ import annotations

import asyncio
import json
import threading
from typing import Awaitable, Callable, Optional

import websockets

PROTOCOL_VERSION = 1
DEFAULT_PORT = 7777

_DIRECTIONS = ("left", "right", "up", "down")


class RemoboardError(Exception):
    """Base error for the Remoboard client."""


class PairingError(RemoboardError):
    """Raised when the phone rejects the PIN."""

    def __init__(self, reason: Optional[str] = None):
        super().__init__(f"Pairing rejected ({reason or 'pin'})")
        self.reason = reason


class RemoboardClient:
    """Async client. Connect, pair with the PIN, then send input.

    Optional callbacks (called from the receive loop):
      on_context(before, after), on_quickwords(list), on_clipboard(text), on_info(text)
    """

    def __init__(
        self,
        host: str,
        pin: str,
        port: int = DEFAULT_PORT,
        pair_timeout: float = 8.0,
        on_context: Optional[Callable[[str, str], None]] = None,
        on_quickwords: Optional[Callable[[list], None]] = None,
        on_clipboard: Optional[Callable[[str], None]] = None,
        on_info: Optional[Callable[[str], None]] = None,
    ):
        if not host:
            raise ValueError("host is required")
        if not pin:
            raise ValueError("pin is required")
        self.host = host
        self.pin = str(pin)
        self.port = port
        self.pair_timeout = pair_timeout
        self.on_context = on_context
        self.on_quickwords = on_quickwords
        self.on_clipboard = on_clipboard
        self.on_info = on_info

        self._ws = None
        self._seq = 0
        self._paired = False
        self._recv_task: Optional[asyncio.Task] = None
        self._paired_event = asyncio.Event()
        self._deny_reason: Optional[str] = None
        self._clip_waiters: "list[asyncio.Future]" = []

    @property
    def url(self) -> str:
        return f"ws://{self.host}:{self.port}/ws"

    @property
    def paired(self) -> bool:
        return self._paired

    # ---- lifecycle ----

    async def connect(self) -> "RemoboardClient":
        """Open the socket and wait until the phone confirms pairing."""
        self._ws = await websockets.connect(self.url, open_timeout=self.pair_timeout)
        self._recv_task = asyncio.ensure_future(self._recv_loop())
        await self._send({"t": "hello", "pin": self.pin})
        try:
            await asyncio.wait_for(self._paired_event.wait(), timeout=self.pair_timeout)
        except asyncio.TimeoutError:
            await self.close()
            if self._deny_reason is not None:
                raise PairingError(self._deny_reason)
            raise RemoboardError(f"Timed out waiting to pair with {self.url}")
        if not self._paired:
            await self.close()
            raise PairingError(self._deny_reason)
        return self

    async def close(self) -> None:
        if self._recv_task:
            self._recv_task.cancel()
            self._recv_task = None
        if self._ws:
            await self._ws.close()
            self._ws = None
        self._paired = False

    async def __aenter__(self) -> "RemoboardClient":
        return await self.connect()

    async def __aexit__(self, *exc) -> None:
        await self.close()

    # ---- receive ----

    async def _recv_loop(self) -> None:
        try:
            async for raw in self._ws:
                try:
                    msg = json.loads(raw)
                except (ValueError, TypeError):
                    continue
                self._handle(msg)
        except (websockets.ConnectionClosed, asyncio.CancelledError):
            pass
        finally:
            for fut in self._clip_waiters:
                if not fut.done():
                    fut.set_exception(RemoboardError("connection closed"))
            self._clip_waiters.clear()

    def _handle(self, msg: dict) -> None:
        t = msg.get("t")
        if t == "paired":
            self._paired = True
            self._paired_event.set()
        elif t == "deny":
            self._deny_reason = msg.get("reason")
            self._paired_event.set()
        elif t == "context":
            if self.on_context:
                self.on_context(msg.get("before", ""), msg.get("after", ""))
        elif t == "quickwords":
            if self.on_quickwords:
                self.on_quickwords(msg.get("items", []))
        elif t == "clip":
            text = msg.get("text", "")
            if self._clip_waiters:
                fut = self._clip_waiters.pop(0)
                if not fut.done():
                    fut.set_result(text)
            if self.on_clipboard:
                self.on_clipboard(text)
        elif t == "info":
            if self.on_info:
                self.on_info(msg.get("message", ""))

    # ---- send ----

    async def _send(self, obj: dict) -> None:
        if self._ws is None:
            raise RemoboardError("not connected")
        await self._ws.send(json.dumps({"v": PROTOCOL_VERSION, **obj}))

    def _require_paired(self) -> None:
        if not self._paired:
            raise RemoboardError("not paired — await connect() first")

    async def type(self, text: str) -> None:
        """Insert text at the phone's cursor."""
        self._require_paired()
        if text:
            await self._send({"t": "input", "text": str(text), "seq": self._next_seq()})

    async def enter(self) -> None:
        """Insert a newline / submit."""
        self._require_paired()
        await self._send({"t": "input", "text": "\n", "seq": self._next_seq()})

    async def backspace(self) -> None:
        """Delete one character backwards."""
        self._require_paired()
        await self._send({"t": "delete", "seq": self._next_seq()})

    async def move(self, direction: str) -> None:
        """Move the cursor: 'left' | 'right' | 'up' | 'down'."""
        self._require_paired()
        if direction not in _DIRECTIONS:
            raise ValueError(f"bad direction: {direction}")
        await self._send({"t": "move", "dir": direction, "seq": self._next_seq()})

    async def set_clipboard(self, text: str) -> None:
        """Write text into the phone's system clipboard."""
        self._require_paired()
        await self._send({"t": "clip-set", "text": str(text)})

    async def get_clipboard(self, timeout: float = 5.0) -> str:
        """Read the phone's clipboard."""
        self._require_paired()
        loop = asyncio.get_event_loop()
        fut: asyncio.Future = loop.create_future()
        self._clip_waiters.append(fut)
        await self._send({"t": "clip-get"})
        try:
            return await asyncio.wait_for(fut, timeout=timeout)
        except asyncio.TimeoutError:
            if fut in self._clip_waiters:
                self._clip_waiters.remove(fut)
            raise RemoboardError("get_clipboard timed out")

    async def set_quick_words(self, words) -> None:
        """Replace the user's quick words on the phone."""
        self._require_paired()
        await self._send({"t": "words-set", "items": [str(w) for w in words]})

    async def handoff(self, text: str) -> None:
        """Hand text to the phone's host app."""
        self._require_paired()
        await self._send({"t": "handoff", "text": str(text)})

    async def ping(self) -> None:
        await self._send({"t": "ping"})

    def _next_seq(self) -> int:
        s = self._seq
        self._seq += 1
        return s


class RemoboardSync:
    """Blocking wrapper around :class:`RemoboardClient`, backed by a private event loop.

    Useful for scripts that don't want to deal with asyncio::

        with RemoboardSync(host="...", pin="...") as rb:
            rb.type("hi")
            rb.enter()
    """

    def __init__(self, host: str, pin: str, port: int = DEFAULT_PORT, **kwargs):
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(target=self._loop.run_forever, daemon=True)
        self._thread.start()
        self._client = RemoboardClient(host=host, pin=pin, port=port, **kwargs)

    def _run(self, coro: Awaitable):
        return asyncio.run_coroutine_threadsafe(coro, self._loop).result()

    def connect(self) -> "RemoboardSync":
        self._run(self._client.connect())
        return self

    def type(self, text: str) -> None:
        self._run(self._client.type(text))

    def enter(self) -> None:
        self._run(self._client.enter())

    def backspace(self) -> None:
        self._run(self._client.backspace())

    def move(self, direction: str) -> None:
        self._run(self._client.move(direction))

    def set_clipboard(self, text: str) -> None:
        self._run(self._client.set_clipboard(text))

    def get_clipboard(self, timeout: float = 5.0) -> str:
        return self._run(self._client.get_clipboard(timeout))

    def set_quick_words(self, words) -> None:
        self._run(self._client.set_quick_words(words))

    def handoff(self, text: str) -> None:
        self._run(self._client.handoff(text))

    def close(self) -> None:
        try:
            self._run(self._client.close())
        finally:
            self._loop.call_soon_threadsafe(self._loop.stop)

    def __enter__(self) -> "RemoboardSync":
        return self.connect()

    def __exit__(self, *exc) -> None:
        self.close()
