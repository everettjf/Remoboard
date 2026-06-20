// Basic Remoboard Node example.
//   REMOBOARD_HOST=192.168.1.20 REMOBOARD_PIN=482103 node examples/basic.mjs
import { RemoboardClient } from '../src/index.js'

const host = process.env.REMOBOARD_HOST || '127.0.0.1'
const pin = process.env.REMOBOARD_PIN || '000000'
const port = Number(process.env.REMOBOARD_PORT || 7777)

const rb = new RemoboardClient({ host, port, pin })

rb.on('context', ({ before, after }) => {
  console.log('phone field:', JSON.stringify(before + '|' + after))
})

await rb.connect()
console.log('paired ✓')

await rb.type('Hello from Node 世界 👋')
await rb.enter()
await rb.type('second line')

await rb.setClipboard('copied by remoboard')
console.log('phone clipboard is now:', await rb.getClipboard())

await new Promise((r) => setTimeout(r, 300))
rb.close()
console.log('done')
