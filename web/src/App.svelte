<script>
  import { onMount } from 'svelte'
  import { Connection } from './connection.js'
  import { t } from './i18n.js'

  // ---- reactive state ----
  let phase = $state('connecting')   // connecting | pairing | paired | reconnecting | denied
  let socketState = $state('connecting')
  let pinInput = $state('')
  let denied = $state(false)
  let buffer = $state('')            // local mirror of what we've sent to the phone
  let phoneBefore = $state('')
  let phoneAfter = $state('')
  let quickWords = $state([])
  let phoneClip = $state(null)
  let clipSend = $state('')
  let copiedFlag = $state(false)
  let toast = $state('')

  // ---- non-reactive ----
  let conn
  let seq = 0
  let lastSent = ''                  // codepoints currently on the phone (== buffer)
  let composing = false
  let textarea = $state(null)

  onMount(() => {
    conn = new Connection({
      onState: (s) => {
        socketState = s
        // Never assume paired on socket open — the server re-pairs every new connection,
        // and treating the socket as paired early drops keystrokes. Wait for the 'paired'
        // message (handleMessage). Keep showing the typing UI during reconnect.
        if (s === 'reconnecting' && phase === 'paired') phase = 'reconnecting'
        if (s === 'open' && phase === 'connecting') phase = 'pairing'
      },
      onMessage: (msg) => handleMessage(msg),
    })
    conn.connect()
    return () => conn.close()
  })

  function handleMessage(msg) {
    switch (msg.t) {
      case 'paired':
        denied = false
        phase = 'paired'
        queueMicrotask(() => textarea && textarea.focus())
        // Resync the baseline to the current buffer rather than replaying a diff: after a
        // reconnect the phone's field may have changed independently, so replaying old
        // deletes/inserts could corrupt it. Future keystrokes diff from here on.
        lastSent = buffer
        break
      case 'deny':
        denied = true
        phase = 'pairing'
        break
      case 'context':
        phoneBefore = msg.before ?? ''
        phoneAfter = msg.after ?? ''
        break
      case 'quickwords':
        quickWords = Array.isArray(msg.items) ? msg.items : []
        break
      case 'clip':
        phoneClip = msg.text ?? ''
        break
      case 'info':
        showToast(msg.message ?? '')
        break
      case 'pong':
        break
    }
  }

  let toastTimer
  function showToast(message) {
    if (!message) return
    toast = message
    clearTimeout(toastTimer)
    toastTimer = setTimeout(() => { toast = '' }, 2200)
  }

  // Single source of truth for the pairing gate: never send an op unless truly paired.
  function gatedSend(obj) {
    if (phase !== 'paired') return false
    return conn.send(obj)
  }

  function getPhoneClip() { gatedSend({ t: 'clip-get' }) }

  function pushPhoneClip() {
    if (!clipSend) return
    if (gatedSend({ t: 'clip-set', text: clipSend })) clipSend = ''
  }

  function sendToApp() {
    if (!buffer) return
    if (gatedSend({ t: 'handoff', text: buffer })) showToast(t('sendToApp'))
  }

  // navigator.clipboard requires a secure context; LAN is plain http, so fall back
  // to the legacy execCommand path.
  async function copyText(text) {
    if (!text) return
    let ok = false
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text)
        ok = true
      }
    } catch {}
    if (!ok) {
      const ta = document.createElement('textarea')
      ta.value = text
      ta.style.position = 'fixed'
      ta.style.opacity = '0'
      document.body.appendChild(ta)
      ta.focus(); ta.select()
      try { ok = document.execCommand('copy') } catch {}
      document.body.removeChild(ta)
    }
    if (ok) { copiedFlag = true; setTimeout(() => { copiedFlag = false }, 1500) }
  }

  function submitPin() {
    const pin = pinInput.trim()
    if (!pin) return
    conn.pair(pin)
  }

  // ---- live diff send ----
  // Compare by codepoints so emoji/surrogate pairs never split.
  function sendDiff(oldStr, newStr) {
    const a = Array.from(oldStr)
    const b = Array.from(newStr)
    let p = 0
    const min = Math.min(a.length, b.length)
    while (p < min && a[p] === b[p]) p++
    const deletions = a.length - p
    const insertion = b.slice(p).join('')
    for (let i = 0; i < deletions; i++) gatedSend({ t: 'delete', seq: seq++ })
    if (insertion.length) gatedSend({ t: 'input', text: insertion, seq: seq++ })
  }

  function syncBuffer() {
    if (composing) return
    if (phase !== 'paired') return   // buffered locally; baseline resynced when 'paired' arrives
    sendDiff(lastSent, buffer)
    lastSent = buffer
  }

  function onInput() {
    if (composing) return
    syncBuffer()
  }

  function onCompositionStart() { composing = true }
  function onCompositionEnd() {
    composing = false
    syncBuffer()
  }

  // When the buffer is empty, keys drive the phone cursor directly.
  function onKeydown(e) {
    if (composing || buffer.length > 0 || phase !== 'paired') return
    let dir = null
    if (e.key === 'Enter') { gatedSend({ t: 'input', text: '\n', seq: seq++ }); e.preventDefault(); return }
    if (e.key === 'Backspace') { gatedSend({ t: 'delete', seq: seq++ }); e.preventDefault(); return }
    if (e.key === 'ArrowLeft') dir = 'left'
    else if (e.key === 'ArrowRight') dir = 'right'
    else if (e.key === 'ArrowUp') dir = 'up'
    else if (e.key === 'ArrowDown') dir = 'down'
    if (dir) { gatedSend({ t: 'move', dir, seq: seq++ }); e.preventDefault() }
  }

  // Clear the local buffer without deleting anything on the phone.
  function clearBuffer() {
    buffer = ''
    lastSent = ''
    textarea && textarea.focus()
  }

  function sendQuickWord(word) {
    gatedSend({ t: 'input', text: word, seq: seq++ })
  }

  let statusLabel = $derived(
    socketState === 'open' ? t('connected')
    : socketState === 'reconnecting' ? t('reconnecting')
    : t('connecting')
  )
  let statusOk = $derived(socketState === 'open')
</script>

<main>
  <header>
    <div class="brand">{t('title')}</div>
    <div class="status" class:ok={statusOk}>
      <span class="dot"></span>{statusLabel}
    </div>
  </header>

  {#if phase === 'paired' || phase === 'reconnecting'}
    <section class="echo">
      <div class="echo-label">{t('onPhone')}</div>
      <div class="echo-body">
        <span class="echo-text">{phoneBefore}</span><span class="caret"></span><span class="echo-text dim">{phoneAfter}</span>
      </div>
    </section>

    <section class="composer">
      <textarea
        bind:this={textarea}
        bind:value={buffer}
        oninput={onInput}
        onkeydown={onKeydown}
        oncompositionstart={onCompositionStart}
        oncompositionend={onCompositionEnd}
        placeholder={t('composeHint')}
        autocapitalize="off"
        autocomplete="off"
        autocorrect="off"
        spellcheck="false"
      ></textarea>
      <div class="composer-row">
        <div class="hint">{t('emptyHintKeys')}</div>
        <button class="ghost" onclick={clearBuffer}>{t('clear')}</button>
      </div>
    </section>

    <section class="quick">
      <div class="quick-label">{t('quickWords')}</div>
      {#if quickWords.length === 0}
        <div class="quick-empty">{t('noQuickWords')}</div>
      {:else}
        <div class="chips">
          {#each quickWords as word}
            <button class="chip" onclick={() => sendQuickWord(word)}>{word}</button>
          {/each}
        </div>
      {/if}
    </section>

    <section class="clip">
      <div class="quick-label">{t('clipboard')}</div>
      <div class="clip-row">
        <input class="clip-input" bind:value={clipSend} placeholder={t('clipPlaceholder')} />
        <button class="ghost" onclick={pushPhoneClip} disabled={!clipSend}>{t('sendPhoneClip')}</button>
      </div>
      <div class="clip-row">
        <button class="ghost" onclick={getPhoneClip}>{t('getPhoneClip')}</button>
        <button class="ghost" onclick={sendToApp} disabled={!buffer}>{t('sendToApp')}</button>
      </div>
      {#if phoneClip !== null}
        <div class="clip-result">
          <div class="clip-text">{phoneClip.length ? phoneClip : t('phoneClipEmpty')}</div>
          {#if phoneClip.length}
            <button class="chip" onclick={() => copyText(phoneClip)}>{copiedFlag ? t('copied') : t('copyHere')}</button>
          {/if}
        </div>
      {/if}
    </section>
  {:else}
    <section class="pairing">
      <div class="lock">⌨</div>
      <p class="pair-hint">{t('enterPin')}</p>
      {#if denied}<p class="error">{t('pinWrong')}</p>{/if}
      <form onsubmit={(e) => { e.preventDefault(); submitPin() }}>
        <input
          class="pin"
          bind:value={pinInput}
          inputmode="numeric"
          placeholder={t('pinPlaceholder')}
          autocomplete="off"
        />
        <button type="submit" class="primary">{t('pair')}</button>
      </form>
    </section>
  {/if}

  {#if toast}
    <div class="toast">{toast}</div>
  {/if}
</main>

<style>
  :global(html, body) {
    margin: 0;
    height: 100%;
    background: #0b0b0f;
    color: #e8e8ef;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  :global(*) { box-sizing: border-box; }

  main {
    max-width: 760px;
    margin: 0 auto;
    padding: 16px 16px 40px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    min-height: 100vh;
  }

  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .brand { font-size: 20px; font-weight: 700; letter-spacing: .5px; }
  .status {
    display: inline-flex; align-items: center; gap: 6px;
    font-size: 13px; color: #9a9aa8;
  }
  .status .dot {
    width: 8px; height: 8px; border-radius: 50%;
    background: #e0a23a; transition: background .2s;
  }
  .status.ok { color: #5ad19a; }
  .status.ok .dot { background: #5ad19a; }

  .echo {
    background: #15151d;
    border: 1px solid #24242f;
    border-radius: 12px;
    padding: 10px 12px;
  }
  .echo-label { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #6c6c7a; margin-bottom: 4px; }
  .echo-body { font-size: 15px; line-height: 1.5; min-height: 22px; word-break: break-word; white-space: pre-wrap; }
  .echo-text.dim { color: #6c6c7a; }
  .caret {
    display: inline-block; width: 2px; height: 1.1em; vertical-align: text-bottom;
    background: #7c6cff; margin: 0 1px; animation: blink 1s steps(1) infinite;
  }
  @keyframes blink { 50% { opacity: 0; } }

  .composer { display: flex; flex-direction: column; gap: 8px; }
  textarea {
    width: 100%;
    min-height: 140px;
    resize: vertical;
    background: #15151d;
    color: #f2f2f7;
    border: 1px solid #2c2c3a;
    border-radius: 12px;
    padding: 14px;
    font-size: 17px;
    line-height: 1.5;
    outline: none;
  }
  textarea:focus { border-color: #7c6cff; }
  .composer-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
  .hint { font-size: 12px; color: #6c6c7a; flex: 1; }

  .quick-label { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #6c6c7a; margin-bottom: 8px; }
  .quick-empty { font-size: 13px; color: #5a5a68; }
  .chips { display: flex; flex-wrap: wrap; gap: 8px; }

  .clip-row { display: flex; gap: 8px; margin-bottom: 8px; align-items: center; }
  .clip-input {
    flex: 1; background: #15151d; color: #f2f2f7; border: 1px solid #2c2c3a;
    border-radius: 8px; padding: 9px 12px; font-size: 15px; outline: none;
  }
  .clip-input:focus { border-color: #7c6cff; }
  .clip-row .ghost { flex: 0 0 auto; }
  .clip-result {
    display: flex; align-items: center; gap: 10px; margin-top: 4px;
    background: #15151d; border: 1px solid #24242f; border-radius: 10px; padding: 10px 12px;
  }
  .clip-text { flex: 1; font-size: 15px; word-break: break-word; white-space: pre-wrap; color: #d8d8e2; }

  .toast {
    position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%);
    background: #2a2a3a; color: #fff; padding: 10px 18px; border-radius: 999px;
    font-size: 14px; box-shadow: 0 6px 24px rgba(0,0,0,.4); z-index: 10;
  }

  button { cursor: pointer; font-family: inherit; }
  .chip {
    background: #1c1c27; color: #d8d8e2; border: 1px solid #2c2c3a;
    border-radius: 999px; padding: 8px 14px; font-size: 15px;
  }
  .chip:active { background: #2a2a3a; }
  .ghost {
    background: transparent; color: #9a9aa8; border: 1px solid #2c2c3a;
    border-radius: 8px; padding: 6px 12px; font-size: 13px; white-space: nowrap;
  }
  .primary {
    background: #7c6cff; color: #fff; border: none;
    border-radius: 10px; padding: 12px 20px; font-size: 16px; font-weight: 600;
  }
  .primary:active { background: #6a5ae0; }

  .pairing {
    margin-top: 8vh;
    display: flex; flex-direction: column; align-items: center; gap: 14px; text-align: center;
  }
  .lock { font-size: 48px; }
  .pair-hint { color: #b6b6c2; font-size: 16px; margin: 0; }
  .error { color: #ff6b6b; font-size: 14px; margin: 0; }
  .pairing form { display: flex; gap: 10px; }
  .pin {
    background: #15151d; color: #f2f2f7; border: 1px solid #2c2c3a;
    border-radius: 10px; padding: 12px 16px; font-size: 22px; letter-spacing: 6px;
    width: 160px; text-align: center; outline: none;
  }
  .pin:focus { border-color: #7c6cff; }

  @media (prefers-color-scheme: light) {
    :global(html, body) { background: #f4f4f7; color: #1a1a22; }
    .echo, textarea, .pin, .clip-input, .clip-result { background: #fff; border-color: #dcdce4; color: #1a1a22; }
    .clip-text { color: #2a2a3a; }
    .chip { background: #fff; color: #2a2a3a; border-color: #dcdce4; }
    .ghost { border-color: #dcdce4; color: #6c6c7a; }
    .status { color: #6c6c7a; }
  }
</style>
