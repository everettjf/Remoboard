// Type definitions for the `remoboard` Node.js client.

import { EventEmitter } from 'node:events'

export const PROTOCOL_VERSION: number
export const DEFAULT_PORT: number

export type MoveDirection = 'left' | 'right' | 'up' | 'down'

export interface RemoboardOptions {
  /** Phone IP or hostname (shown on the keyboard). */
  host: string
  /** Server port (default 7777). */
  port?: number
  /** Pairing PIN shown on the keyboard. */
  pin: string
  /** ms to wait for the `paired` reply (default 8000). */
  pairTimeout?: number
  /** Auto-reconnect (and re-pair) on drop (default false). */
  reconnect?: boolean
}

export interface ContextEvent {
  before: string
  after: string
}

export class PairingError extends Error {
  reason?: string
}

export interface RemoboardClient {
  on(event: 'connected', listener: () => void): this
  on(event: 'paired', listener: () => void): this
  on(event: 'context', listener: (ctx: ContextEvent) => void): this
  on(event: 'quickwords', listener: (words: string[]) => void): this
  on(event: 'clipboard', listener: (text: string) => void): this
  on(event: 'info', listener: (message: string) => void): this
  on(event: 'close', listener: () => void): this
  on(event: 'error', listener: (err: Error) => void): this
}

export class RemoboardClient extends EventEmitter {
  constructor(options: RemoboardOptions)
  readonly url: string
  readonly paired: boolean
  connect(): Promise<this>
  type(text: string): this
  enter(): this
  backspace(): this
  move(dir: MoveDirection): this
  setClipboard(text: string): this
  getClipboard(opts?: { timeout?: number }): Promise<string>
  setQuickWords(words: string[]): this
  handoff(text: string): this
  ping(): this
  close(): void
}

export default RemoboardClient
