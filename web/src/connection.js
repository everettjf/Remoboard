// WebSocket transport with exponential-backoff reconnect and a heartbeat.
// Replaces the legacy setInterval-leaking reconnect loop.

export class Connection {
  constructor({ onState, onMessage }) {
    this.onState = onState || (() => {})
    this.onMessage = onMessage || (() => {})
    this.ws = null
    this.pin = null
    this.backoff = 500
    this.maxBackoff = 8000
    this.heartbeat = null
    this.heartbeatMs = 10000
    this.lastRx = 0
    this.reconnectTimer = null
    this.closedByUser = false
  }

  connect() {
    this.closedByUser = false
    this._open()
  }

  _open() {
    this._cleanupSocket()
    this.onState('connecting')

    let ws
    try {
      ws = new WebSocket(`ws://${location.host}/ws`)
    } catch (e) {
      this._scheduleReconnect()
      return
    }
    this.ws = ws

    ws.onopen = () => {
      this.backoff = 500
      this.onState('open')
      if (this.pin) this.send({ t: 'hello', pin: this.pin })
      this._startHeartbeat()
    }
    ws.onmessage = (ev) => {
      this.lastRx = Date.now()
      let msg
      try { msg = JSON.parse(ev.data) } catch { return }
      this.onMessage(msg)
    }
    ws.onerror = () => { /* close handler drives reconnect */ }
    ws.onclose = () => {
      this._stopHeartbeat()
      if (this.closedByUser) return
      this.onState('reconnecting')
      this._scheduleReconnect()
    }
  }

  pair(pin) {
    this.pin = pin
    this.send({ t: 'hello', pin })
  }

  send(obj) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(obj))
      return true
    }
    return false
  }

  _startHeartbeat() {
    this._stopHeartbeat()
    this.lastRx = Date.now()
    this.heartbeat = setInterval(() => {
      // A custom keyboard gets suspended when the phone sleeps or the host app
      // backgrounds. The TCP socket then stays "open" at the OS level for minutes
      // while the server is frozen, so sends silently vanish and typing appears
      // dead. If we've heard nothing back across two beats, treat the link as gone
      // and reconnect — the keyboard re-pairs (or re-prompts for the PIN) on the new
      // socket, which restores typing.
      if (Date.now() - this.lastRx > this.heartbeatMs * 2) {
        this._forceReconnect()
        return
      }
      this.send({ t: 'ping' })
    }, this.heartbeatMs)
  }

  _forceReconnect() {
    if (this.closedByUser) return
    this._stopHeartbeat()
    this.onState('reconnecting')
    this._open()   // _cleanupSocket() inside drops the stale socket without firing onclose
  }

  _stopHeartbeat() {
    if (this.heartbeat) { clearInterval(this.heartbeat); this.heartbeat = null }
  }

  _scheduleReconnect() {
    if (this.reconnectTimer) return
    const delay = this.backoff
    this.backoff = Math.min(this.backoff * 2, this.maxBackoff)
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null
      this._open()
    }, delay)
  }

  _cleanupSocket() {
    if (this.ws) {
      this.ws.onopen = this.ws.onmessage = this.ws.onerror = this.ws.onclose = null
      try { this.ws.close() } catch {}
      this.ws = null
    }
  }

  close() {
    this.closedByUser = true
    this._stopHeartbeat()
    if (this.reconnectTimer) { clearTimeout(this.reconnectTimer); this.reconnectTimer = null }
    this._cleanupSocket()
  }
}
