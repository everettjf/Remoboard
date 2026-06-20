"""Basic Remoboard Python example.

    REMOBOARD_HOST=192.168.1.20 REMOBOARD_PIN=482103 python examples/basic.py
"""

import asyncio
import os

from remoboard import RemoboardClient


async def main():
    host = os.environ.get("REMOBOARD_HOST", "127.0.0.1")
    pin = os.environ.get("REMOBOARD_PIN", "000000")
    port = int(os.environ.get("REMOBOARD_PORT", "7777"))

    async with RemoboardClient(
        host=host,
        port=port,
        pin=pin,
        on_context=lambda b, a: print("phone field:", repr(b + "|" + a)),
    ) as rb:
        print("paired ✓")
        await rb.type("Hello from Python 世界 👋")
        await rb.enter()
        await rb.type("second line")

        await rb.set_clipboard("copied by remoboard")
        print("phone clipboard is now:", await rb.get_clipboard())
        await asyncio.sleep(0.3)
    print("done")


if __name__ == "__main__":
    asyncio.run(main())
