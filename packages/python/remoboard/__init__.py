"""Remoboard Python client.

Drive remote text input on a phone running the Remoboard keyboard, over the versioned
JSON protocol (v1) carried on a WebSocket.

Async::

    import asyncio
    from remoboard import RemoboardClient

    async def main():
        async with RemoboardClient(host="192.168.1.20", pin="482103") as rb:
            await rb.type("Hello 世界")
            await rb.enter()

    asyncio.run(main())

Sync::

    from remoboard import RemoboardSync

    with RemoboardSync(host="192.168.1.20", pin="482103") as rb:
        rb.type("Hello 世界")
        rb.enter()
"""

from .client import (
    RemoboardClient,
    RemoboardSync,
    PairingError,
    RemoboardError,
    PROTOCOL_VERSION,
    DEFAULT_PORT,
)

__all__ = [
    "RemoboardClient",
    "RemoboardSync",
    "PairingError",
    "RemoboardError",
    "PROTOCOL_VERSION",
    "DEFAULT_PORT",
]
__version__ = "1.0.0"
