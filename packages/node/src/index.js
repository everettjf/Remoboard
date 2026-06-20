// Remoboard Node.js client.
//
// Connects to the WebSocket server hosted by the Remoboard keyboard extension on a phone
// and drives remote text input over the versioned JSON protocol (v1).
//
//   import { RemoboardClient } from 'remoboard'
//   const rb = new RemoboardClient({ host: '192.168.1.20', pin: '482103' })
//   await rb.connect()
//   await rb.type('Hello 世界')
//   await rb.enter()
//   await rb.close()

import WebSocket from 'ws'
import { EventEmitter } from 'node:events'

export const PROTOCOL_VERSION = 1
export const DEFAULT_PORT = 7777

/** Error thrown when the phone rejects the PIN. */
export class PairingError extends Error {
  constructor(reason) {
    super(`Pairing rejected (${reason || 'pin'})`)
    this.name = 'PairingError'
    this.reason = reason
  }
}

/**
 * @typedef {Object} RemoboardOptions
 * @property {string} host           Phone IP or hostname (shown on the keyboard).
 * @property {number} [port=7777]    Server port.
 * @property {string} pin            Pairing PIN shown on the keyboard.
 * @property {number} [pairTimeout=8000] ms to wait for the `paired` reply.
 * @property {boolean} [reconnect=false] auto-reconnect (re-pairs) on drop.
 */

/**
 * Events: 'connected', 'paired', 'context' ({before, after}), 'quickwords' (string[]),
 *         'clipboard' (string), 'info' (string), 'close', 'error'.
 */
export class RemoboardClient extends EventEmitter {
  /** @param {RemoboardOptions} options */
  constructor(options) {
    super()
    if (!options || !options.host) throw new Error('host is required')
    if (!options.pin) throw new Error('pin is required')
    this.host = options.host
    this.port = options.port ?? DEFAULT_PORT
    this.pin = String(options.pin)
    this.pairTimeout = options.pairTimeout ?? 8000
    this.autoReconnect = options.reconnect ?? false

    this._ws = null
    this._seq = 0
    this._paired = false
    this._closedByUser = false
    /** @type {((clip: string) => void)[]} queued getClipboard resolvers */
    this._clipWaiters = []
  }

  get url() {
    return `ws://${this.host}:${this.port}/ws`
  }

  get paired() {
    return this._paired
  }

  /** Opens the socket and resolves once the phone confirms pairing. */
  connect() {
    this._closedByUser = false
    return new Promise((resolve, reject) => {
      let settled = false
      const ws = new WebSocket(this.url)
      this._ws = ws

      const timer = setTimeout(() => {
        if (settled) return
        settled = true
        ws.close()
        reject(new Error(`Timed out waiting to pair with ${this.url}`))
      }, this.pairTimeout)

      ws.on('open', () => {
        this.emit('connected')
        this._send({ t: 'hello', pin: this.pin })
      })

      ws.on('message', (data) => {
        let msg
        try { msg = JSON.parse(data.toString()) } catch { return }
        this._handle(msg)
        if (!settled && msg.t === 'paired') {
          settled = true
          clearTimeout(timer)
          resolve(this)
        } else if (!settled && msg.t === 'deny') {
          settled = true
          clearTimeout(timer)
          reject(new PairingError(msg.reason))
        }
      })

      ws.on('error', (err) => {
        this.emit('error', err)
        if (!settled) { settled = true; clearTimeout(timer); reject(err) }
      })

      ws.on('close', () => {
        this._paired = false
        this.emit('close')
        this._failClipWaiters(new Error('connection closed'))
        if (this.autoReconnect && !this._closedByUser) {
          setTimeout(() => this.connect().catch(() => {}), 1000)
        }
      })
    })
  }

  _handle(msg) {
    switch (msg.t) {
      case 'paired':
        this._paired = true
        this.emit('paired')
        break
      case 'context':
        this.emit('context', { before: msg.before ?? '', after: msg.after ?? '' })
        break
      case 'quickwords':
        this.emit('quickwords', Array.isArray(msg.items) ? msg.items : [])
        break
      case 'clip': {
        const text = msg.text ?? ''
        const w = this._clipWaiters.shift()
        if (w) w(text)
        this.emit('clipboard', text)
        break
      }
      case 'info':
        this.emit('info', msg.message ?? '')
        break
      case 'pong':
      case 'deny':
        break
    }
  }

  _send(obj) {
    if (!this._ws || this._ws.readyState !== WebSocket.OPEN) {
      throw new Error('not connected')
    }
    this._ws.send(JSON.stringify({ v: PROTOCOL_VERSION, ...obj }))
  }

  _requirePaired() {
    if (!this._paired) throw new Error('not paired — await connect() first')
  }

  // ---- input ----

  /** Insert text at the phone's cursor. */
  type(text) {
    this._requirePaired()
    if (text) this._send({ t: 'input', text: String(text), seq: this._seq++ })
    return this
  }

  /** Insert a newline / submit. */
  enter() {
    this._requirePaired()
    this._send({ t: 'input', text: '\n', seq: this._seq++ })
    return this
  }

  /** Delete one character backwards. */
  backspace() {
    this._requirePaired()
    this._send({ t: 'delete', seq: this._seq++ })
    return this
  }

  /** Move the cursor. @param {'left'|'right'|'up'|'down'} dir */
  move(dir) {
    this._requirePaired()
    if (!['left', 'right', 'up', 'down'].includes(dir)) throw new Error(`bad direction: ${dir}`)
    this._send({ t: 'move', dir, seq: this._seq++ })
    return this
  }

  // ---- clipboard ----

  /** Write text into the phone's system clipboard. */
  setClipboard(text) {
    this._requirePaired()
    this._send({ t: 'clip-set', text: String(text) })
    return this
  }

  /** Read the phone's clipboard. Resolves with the text. */
  getClipboard({ timeout = 5000 } = {}) {
    this._requirePaired()
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const i = this._clipWaiters.indexOf(onClip)
        if (i >= 0) this._clipWaiters.splice(i, 1)
        reject(new Error('getClipboard timed out'))
      }, timeout)
      const onClip = (text) => { clearTimeout(timer); resolve(text) }
      this._clipWaiters.push(onClip)
      this._send({ t: 'clip-get' })
    })
  }

  // ---- misc ----

  /** Replace the user's quick words on the phone. @param {string[]} words */
  setQuickWords(words) {
    this._requirePaired()
    this._send({ t: 'words-set', items: words.map(String) })
    return this
  }

  /** Hand text to the phone's host app (e.g. for Continuity handoff). */
  handoff(text) {
    this._requirePaired()
    this._send({ t: 'handoff', text: String(text) })
    return this
  }

  /** Liveness check. */
  ping() {
    this._send({ t: 'ping' })
    return this
  }

  _failClipWaiters(err) {
    const waiters = this._clipWaiters
    this._clipWaiters = []
    for (const _ of waiters) { /* resolvers reject via their own timers */ }
    void err
  }

  /** Close the connection. */
  close() {
    this._closedByUser = true
    this._paired = false
    if (this._ws) { try { this._ws.close() } catch {} this._ws = null }
  }
}

export default RemoboardClient
