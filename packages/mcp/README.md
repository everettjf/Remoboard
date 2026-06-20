# remoboard-mcp

A [Model Context Protocol](https://modelcontextprotocol.io) server for
[Remoboard](https://github.com/everettjf/Remoboard) — lets an AI assistant (Claude, etc.)
type into your phone running the Remoboard keyboard.

## What it does

The server connects to the Remoboard keyboard on your phone and exposes its remote input
as MCP tools, so an assistant can insert text, press keys, and read/write the phone's
clipboard.

## Tools

| Tool                       | Description                                                       |
| -------------------------- | ---------------------------------------------------------------- |
| `remoboard_type`           | Type text at the cursor (any Unicode, incl. emoji/CJK).          |
| `remoboard_press`          | Press a control key: `enter`, `backspace`, `left/right/up/down`. |
| `remoboard_set_clipboard`  | Write text into the phone's system clipboard.                    |
| `remoboard_get_clipboard`  | Read the phone's system clipboard.                               |
| `remoboard_get_context`    | Get the text around the cursor in the focused phone field.       |

## Configuration

On the phone: switch to the Remoboard keyboard. It shows a URL like `http://192.168.1.20:7777`
and a **PIN**. Configure the server with environment variables:

| Variable         | Required | Default | Description                       |
| ---------------- | -------- | ------- | --------------------------------- |
| `REMOBOARD_HOST` | yes      | —       | Phone IP/hostname.                |
| `REMOBOARD_PIN`  | yes      | —       | Pairing PIN shown on the keyboard.|
| `REMOBOARD_PORT` | no       | `7777`  | Server port.                      |

### Claude Desktop / Claude Code

Add to your MCP config (e.g. `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "remoboard": {
      "command": "npx",
      "args": ["-y", "remoboard-mcp"],
      "env": {
        "REMOBOARD_HOST": "192.168.1.20",
        "REMOBOARD_PIN": "482103"
      }
    }
  }
}
```

Or with Claude Code:

```bash
claude mcp add remoboard --env REMOBOARD_HOST=192.168.1.20 --env REMOBOARD_PIN=482103 -- npx -y remoboard-mcp
```

## Run locally (from this repo)

```bash
cd packages/mcp
npm install
REMOBOARD_HOST=192.168.1.20 REMOBOARD_PIN=482103 node src/server.js
```

The PIN changes only when the keyboard process restarts, so update `REMOBOARD_PIN` if
pairing starts failing.

## License

MIT.
