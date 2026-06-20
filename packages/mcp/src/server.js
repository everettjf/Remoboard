#!/usr/bin/env node
// Remoboard MCP server.
//
// Exposes the Remoboard remote keyboard as MCP tools so an AI assistant can type into a
// phone running the Remoboard keyboard. Configure with env vars:
//   REMOBOARD_HOST  phone IP/hostname shown on the keyboard (required)
//   REMOBOARD_PIN   pairing PIN shown on the keyboard (required)
//   REMOBOARD_PORT  server port (default 7777)
//
// Transport: stdio.

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'
import { RemoboardClient } from 'remoboard'

const HOST = process.env.REMOBOARD_HOST
const PIN = process.env.REMOBOARD_PIN
const PORT = Number(process.env.REMOBOARD_PORT || 7777)

if (!HOST || !PIN) {
  console.error('remoboard-mcp: set REMOBOARD_HOST and REMOBOARD_PIN environment variables.')
  process.exit(1)
}

// Lazily (re)connect so the MCP server starts even if the phone isn't reachable yet.
let client = null
let lastContext = { before: '', after: '' }

async function getClient() {
  if (client && client.paired) return client
  const rb = new RemoboardClient({ host: HOST, port: PORT, pin: PIN, reconnect: false })
  rb.on('context', (ctx) => { lastContext = ctx })
  await rb.connect()
  client = rb
  return rb
}

function ok(text) {
  return { content: [{ type: 'text', text }] }
}
function fail(err) {
  return { content: [{ type: 'text', text: `Error: ${err?.message || err}` }], isError: true }
}

const server = new McpServer({ name: 'remoboard', version: '1.0.0' })

server.tool(
  'remoboard_type',
  'Type text into the phone at the current cursor position. Supports any Unicode (incl. emoji and CJK).',
  { text: z.string().describe('The text to insert on the phone.') },
  async ({ text }) => {
    try { (await getClient()).type(text); return ok(`Typed ${[...text].length} characters.`) }
    catch (e) { return fail(e) }
  }
)

server.tool(
  'remoboard_press',
  'Press a control key on the phone keyboard.',
  {
    key: z.enum(['enter', 'backspace', 'left', 'right', 'up', 'down'])
      .describe('enter = newline/submit, backspace = delete one char, arrows = move cursor.'),
  },
  async ({ key }) => {
    try {
      const rb = await getClient()
      if (key === 'enter') rb.enter()
      else if (key === 'backspace') rb.backspace()
      else rb.move(key)
      return ok(`Pressed ${key}.`)
    } catch (e) { return fail(e) }
  }
)

server.tool(
  'remoboard_set_clipboard',
  "Write text into the phone's system clipboard.",
  { text: z.string().describe('Text to place on the phone clipboard.') },
  async ({ text }) => {
    try { (await getClient()).setClipboard(text); return ok('Phone clipboard updated.') }
    catch (e) { return fail(e) }
  }
)

server.tool(
  'remoboard_get_clipboard',
  "Read the phone's system clipboard.",
  {},
  async () => {
    try {
      const rb = await getClient()
      const text = await rb.getClipboard()
      return ok(text)
    } catch (e) { return fail(e) }
  }
)

server.tool(
  'remoboard_get_context',
  'Get the text around the cursor in the phone field the keyboard is focused on.',
  {},
  async () => {
    try {
      await getClient()
      return ok(JSON.stringify(lastContext))
    } catch (e) { return fail(e) }
  }
)

const transport = new StdioServerTransport()
await server.connect(transport)
console.error(`remoboard-mcp: connected to MCP; targeting ${HOST}:${PORT}`)
