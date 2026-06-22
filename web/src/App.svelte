<script>
  import { onMount } from 'svelte'
  import { Connection } from './connection.js'
  import { translate, detectLang, availableLangs } from './i18n.js'
  import { loadThemePref, saveThemePref, applyTheme, watchSystem } from './theme.js'

  // localStorage can throw (Safari private mode / sandboxed contexts) — never let it crash init.
  const safeGet = (k) => { try { return localStorage.getItem(k) } catch { return null } }
  const safeSet = (k, v) => { try { localStorage.setItem(k, v) } catch {} }

  // ---- settings (persisted) ----
  let themePref = $state(loadThemePref())                                  // system | light | dark
  let langPref = $state(safeGet('rkb-lang') || 'auto')                     // auto | <lang code>
  let inputMode = $state(safeGet('rkb-mode') === 'send' ? 'send' : 'live') // live | send
  let settingsOpen = $state(false)

  let lang = $derived(langPref === 'auto' ? detectLang() : langPref)
  const t = (k) => translate(k, lang)

  // ---- connection / session ----
  let phase = $state('connecting')   // connecting | pairing | paired | reconnecting | denied
  let socketState = $state('connecting')
  let pinInput = $state('')
  let denied = $state(false)

  // ---- editor ----
  let buffer = $state('')
  let textarea = $state(null)

  // ---- features ----
  let quickWords = $state([])
  let editingWords = $state(false)
  let newWord = $state('')
  let phoneClip = $state(null)
  let clipSend = $state('')
  let copiedFlag = $state(false)
  let history = $state([])
  let toast = $state('')

  // ---- non-reactive ----
  let conn
  let seq = 0
  let lastSent = ''
  let phoneCaret = 0   // our belief of the phone caret, in codepoints within lastSent
  let composing = false
  let toastTimer
  let pairGraceTimer

  // ---- theme application ----
  $effect(() => { applyTheme(themePref) })
  onMount(() => watchSystem(() => { if (themePref === 'system') applyTheme(themePref) }))

  onMount(() => {
    conn = new Connection({
      onState: (s) => {
        socketState = s
        if (s === 'reconnecting' && phase === 'paired') phase = 'reconnecting'
        // When the socket opens, give the server a beat to auto-pair (no-PIN mode)
        // before revealing the PIN screen — otherwise it flashes for a frame.
        if (s === 'open' && phase === 'connecting') {
          clearTimeout(pairGraceTimer)
          pairGraceTimer = setTimeout(() => { if (phase === 'connecting') phase = 'pairing' }, 600)
        }
      },
      onMessage: (msg) => handleMessage(msg),
    })
    conn.connect()
    return () => conn.close()
  })

  function persistTheme(p) { themePref = p; saveThemePref(p) }
  function persistLang(l) { langPref = l; safeSet('rkb-lang', l) }
  // Switching modes starts fresh so the two models never get tangled (the old draft, if
  // any, is stashed to Recent by clearBuffer so it's not lost).
  function setMode(m) {
    if (m === inputMode) return
    clearBuffer()
    inputMode = m
    safeSet('rkb-mode', m)
    textarea && textarea.focus()
  }

  function handleMessage(msg) {
    switch (msg.t) {
      case 'paired':
        denied = false
        phase = 'paired'
        queueMicrotask(() => textarea && textarea.focus())
        if (buffer.startsWith(lastSent) && buffer.length > lastSent.length) {
          gatedSend({ t: 'input', text: buffer.slice(lastSent.length), seq: seq++ })
        }
        lastSent = buffer
        phoneCaret = Array.from(buffer).length   // resync: the phone caret is at the end
        break
      case 'deny':
        denied = true
        phase = 'pairing'
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

  function showToast(message) {
    if (!message) return
    toast = message
    clearTimeout(toastTimer)
    toastTimer = setTimeout(() => { toast = '' }, 2200)
  }

  // Single source of truth for the pairing gate.
  function gatedSend(obj) {
    if (phase !== 'paired') return false
    return conn.send(obj)
  }

  // ---- caret-aware live mirror ----
  // The box is a true mirror of what we've typed on the phone, including caret position,
  // so editing/moving in the middle stays in sync instead of being appended. We work in
  // codepoints throughout so emoji (surrogate pairs) are never split.
  function cps(str) { return Array.from(str) }
  // The textarea caret (UTF-16 selectionStart) as a codepoint offset.
  function webCaretCp() {
    const u16 = textarea ? textarea.selectionStart : buffer.length
    return Array.from(buffer.slice(0, u16)).length
  }
  // Walk the phone caret to an absolute codepoint offset using single-step moves; the phone
  // only understands directional moves, so we emit the exact left/right delta ourselves.
  function moveCaretTo(targetCp) {
    while (phoneCaret > targetCp) { gatedSend({ t: 'move', dir: 'left', seq: seq++ }); phoneCaret-- }
    while (phoneCaret < targetCp) { gatedSend({ t: 'move', dir: 'right', seq: seq++ }); phoneCaret++ }
  }

  // Reconcile the phone with the box: a single contiguous edit (prefix + suffix match)
  // applied at the right caret position, then align the caret with the box.
  function syncToPhone() {
    if (composing || phase !== 'paired') return
    const oldA = cps(lastSent), newA = cps(buffer)
    let p = 0
    const min = Math.min(oldA.length, newA.length)
    while (p < min && oldA[p] === newA[p]) p++
    let s = 0
    while (s < min - p && oldA[oldA.length - 1 - s] === newA[newA.length - 1 - s]) s++
    const delCount = oldA.length - p - s
    const insA = newA.slice(p, newA.length - s)
    if (delCount > 0 || insA.length > 0) {
      moveCaretTo(oldA.length - s)                 // caret at the end of the changed region
      for (let i = 0; i < delCount; i++) { gatedSend({ t: 'delete', seq: seq++ }); phoneCaret-- }
      if (insA.length) { gatedSend({ t: 'input', text: insA.join(''), seq: seq++ }); phoneCaret += insA.length }
      lastSent = buffer
    }
    moveCaretTo(webCaretCp())
  }

  // Caret moved in the box (arrow keys, click) without changing text — mirror just the move.
  function syncCaret() {
    if (inputMode !== 'live' || composing || phase !== 'paired' || buffer !== lastSent) return
    moveCaretTo(webCaretCp())
  }

  function onInput() { if (!composing && inputMode === 'live') syncToPhone() }
  function onCompositionStart() { composing = true }
  function onCompositionEnd() { composing = false; if (inputMode === 'live') syncToPhone() }

  // Send mode: compose locally, push the whole message on demand, then clear.
  function sendMessage() {
    if (!buffer) return
    if (gatedSend({ t: 'input', text: buffer, seq: seq++ })) clearBuffer()
  }

  function onKeydown(e) {
    if (composing || phase !== 'paired') return

    if (inputMode === 'send') {
      // ⌘/Ctrl + Enter sends; plain Enter stays a newline so you can compose multi-line.
      if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); sendMessage() }
      return
    }

    // Live mode. With an empty box there's no local text to navigate, so keys drive the
    // phone's caret directly — "remote control" (also reaches text already on the phone).
    if (buffer.length === 0) {
      let dir = null
      if (e.key === 'ArrowLeft') dir = 'left'
      else if (e.key === 'ArrowRight') dir = 'right'
      else if (e.key === 'ArrowUp') dir = 'up'
      else if (e.key === 'ArrowDown') dir = 'down'
      if (dir) { gatedSend({ t: 'move', dir, seq: seq++ }); e.preventDefault(); return }
      if (e.key === 'Enter') { gatedSend({ t: 'input', text: '\n', seq: seq++ }); e.preventDefault(); return }
      if (e.key === 'Backspace') { gatedSend({ t: 'delete', seq: seq++ }); e.preventDefault(); return }
      return
    }

    // Text in the box: if an arrow would move past the edge of the draft, hand cursor control
    // to the phone. The draft is already mirrored there, so stash it (recoverable from Recent),
    // clear our local copy, and send the raw move — further arrows then drive the phone caret
    // directly (remote-control mode), instead of dying at the box boundary.
    const caret = textarea ? textarea.selectionStart : buffer.length
    let overflow = null
    if ((e.key === 'ArrowLeft' || e.key === 'ArrowUp') && caret === 0) overflow = e.key === 'ArrowLeft' ? 'left' : 'up'
    else if ((e.key === 'ArrowRight' || e.key === 'ArrowDown') && caret >= buffer.length) overflow = e.key === 'ArrowRight' ? 'right' : 'down'
    if (overflow) {
      e.preventDefault()
      clearBuffer()
      gatedSend({ t: 'move', dir: overflow, seq: seq++ })
      return
    }
    // Otherwise let the textarea move its own caret / edit; onKeyup + onInput mirror the
    // result to the phone (no clearing, caret stays in sync).
  }

  function onKeyup(e) {
    if (inputMode !== 'live') return
    if (e.key === 'ArrowLeft' || e.key === 'ArrowRight' || e.key === 'ArrowUp' ||
        e.key === 'ArrowDown' || e.key === 'Home' || e.key === 'End') syncCaret()
  }

  function clearBuffer() {
    const snip = buffer.trim()
    if (snip) history = [snip, ...history.filter((h) => h !== snip)].slice(0, 12)
    buffer = ''
    lastSent = ''
    phoneCaret = 0
    textarea && textarea.focus()
  }

  function resend(text) {
    gatedSend({ t: 'input', text, seq: seq++ })
  }

  function sendQuickWord(word) { gatedSend({ t: 'input', text: word, seq: seq++ }) }

  // On-screen pad. With text in the box, move the box's own caret and let syncCaret mirror it
  // (keeps everything in sync, no clearing). With an empty box, drive the phone directly.
  function moveCursor(dir) {
    if (phase !== 'paired') return
    if (buffer.length === 0) { gatedSend({ t: 'move', dir, seq: seq++ }); return }
    if (textarea) {
      if (dir === 'left' || dir === 'right') moveCaretChars(dir === 'left' ? -1 : 1)
      else moveCaretLine(dir === 'up' ? -1 : 1)
      syncCaret()
    }
    textarea && textarea.focus()
  }
  function phoneDelete() {
    if (phase !== 'paired') return
    if (buffer.length === 0) { gatedSend({ t: 'delete', seq: seq++ }); return }
    const pos = textarea ? textarea.selectionStart : buffer.length
    if (pos <= 0) return
    const beforeArr = Array.from(buffer.slice(0, pos))
    const removed = beforeArr[beforeArr.length - 1] ?? ''
    if (!removed) return
    moveCaretTo(beforeArr.length)                 // align phone caret with the box caret
    gatedSend({ t: 'delete', seq: seq++ }); phoneCaret--
    const newPos = pos - removed.length
    buffer = buffer.slice(0, newPos) + buffer.slice(pos)
    lastSent = buffer
    queueMicrotask(() => { textarea && textarea.setSelectionRange(newPos, newPos); textarea && textarea.focus() })
  }

  // Move the box caret by whole codepoints (so emoji move as one).
  function moveCaretChars(delta) {
    if (!textarea) return
    const pos = textarea.selectionStart
    let target = pos
    if (delta < 0) { const b = Array.from(buffer.slice(0, pos)); target = pos - (b[b.length - 1]?.length ?? 1) }
    else { const after = buffer.slice(pos); const ch = Array.from(after)[0]; target = pos + (ch?.length ?? 0) }
    target = Math.max(0, Math.min(buffer.length, target))
    textarea.setSelectionRange(target, target)
  }
  // Move the box caret up/down one visual line, keeping the column.
  function moveCaretLine(delta) {
    if (!textarea) return
    const pos = textarea.selectionStart
    const lineStart = buffer.lastIndexOf('\n', pos - 1) + 1
    const col = pos - lineStart
    let target
    if (delta < 0) {
      if (lineStart === 0) { target = 0 }
      else { const prevStart = buffer.lastIndexOf('\n', lineStart - 2) + 1; target = Math.min(prevStart + col, lineStart - 1) }
    } else {
      const lineEnd = buffer.indexOf('\n', pos)
      if (lineEnd < 0) { target = buffer.length }
      else { const nextStart = lineEnd + 1; const ne = buffer.indexOf('\n', nextStart); const nextEnd = ne < 0 ? buffer.length : ne; target = Math.min(nextStart + col, nextEnd) }
    }
    textarea.setSelectionRange(target, target)
  }

  // ---- quick words management (synced to phone) ----
  // Only apply the edit locally if it was actually sent — otherwise the UI would show
  // words the phone never received (and a rebroadcast would silently revert them).
  function pushWords(words) {
    if (!gatedSend({ t: 'words-set', items: words })) return false
    quickWords = words
    return true
  }
  function addWord() {
    const w = newWord.trim()
    if (!w) return
    if (pushWords([...quickWords, w])) newWord = ''
  }
  function removeWord(i) { pushWords(quickWords.filter((_, idx) => idx !== i)) }
  function moveWord(i, delta) {
    const j = i + delta
    if (j < 0 || j >= quickWords.length) return
    const copy = [...quickWords]
    ;[copy[i], copy[j]] = [copy[j], copy[i]]
    pushWords(copy)
  }

  // ---- clipboard ----
  function getPhoneClip() { gatedSend({ t: 'clip-get' }) }
  function pushPhoneClip() {
    if (!clipSend) return
    if (gatedSend({ t: 'clip-set', text: clipSend })) clipSend = ''
  }
  function sendToApp() {
    if (!buffer) return
    if (gatedSend({ t: 'handoff', text: buffer })) showToast(t('sendToApp'))
  }

  async function copyText(text) {
    if (!text) return
    let ok = false
    try {
      if (navigator.clipboard && window.isSecureContext) { await navigator.clipboard.writeText(text); ok = true }
    } catch {}
    if (!ok) {
      const ta = document.createElement('textarea')
      ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0'
      document.body.appendChild(ta); ta.focus(); ta.select()
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
    <div class="head-right">
      <div class="status" class:ok={statusOk}><span class="dot"></span>{statusLabel}</div>
      <button class="icon-btn" aria-label={t('settings')} onclick={() => (settingsOpen = true)}>⚙</button>
    </div>
  </header>

  {#if phase === 'paired' || phase === 'reconnecting'}
    <section class="composer">
      <div class="mode-row" role="tablist" aria-label={t('inputMode')}>
        <button class="seg" class:active={inputMode === 'live'} role="tab" aria-selected={inputMode === 'live'} onclick={() => setMode('live')}>{t('modeLive')}</button>
        <button class="seg" class:active={inputMode === 'send'} role="tab" aria-selected={inputMode === 'send'} onclick={() => setMode('send')}>{t('modeSend')}</button>
      </div>

      <textarea
        bind:this={textarea}
        bind:value={buffer}
        oninput={onInput}
        onkeydown={onKeydown}
        onkeyup={onKeyup}
        onclick={syncCaret}
        oncompositionstart={onCompositionStart}
        oncompositionend={onCompositionEnd}
        placeholder={inputMode === 'send' ? t('composeHintSend') : t('composeHint')}
        autocapitalize="off" autocomplete="off" autocorrect="off" spellcheck="false"
      ></textarea>

      <div class="composer-row">
        {#if inputMode === 'live'}
          <div class="cursor-pad" aria-label={t('cursorControls')}>
            <button class="cbtn" title={t('cursorLeft')} aria-label={t('cursorLeft')} onclick={() => moveCursor('left')}>←</button>
            <button class="cbtn" title={t('cursorUp')} aria-label={t('cursorUp')} onclick={() => moveCursor('up')}>↑</button>
            <button class="cbtn" title={t('cursorDown')} aria-label={t('cursorDown')} onclick={() => moveCursor('down')}>↓</button>
            <button class="cbtn" title={t('cursorRight')} aria-label={t('cursorRight')} onclick={() => moveCursor('right')}>→</button>
            <button class="cbtn" title={t('cursorDelete')} aria-label={t('cursorDelete')} onclick={phoneDelete}>⌫</button>
          </div>
        {:else}
          <button class="btn primary sm" disabled={!buffer} onclick={sendMessage}>{t('send')}</button>
        {/if}
        <div class="composer-right">
          <span class="count">{Array.from(buffer).length} {t('chars')}</span>
          <button class="btn ghost sm" title={t('clearHint')} onclick={clearBuffer}>{t('clear')}</button>
        </div>
      </div>
      <div class="hint">{inputMode === 'send' ? t('sendHint') : t('emptyHintKeys')}</div>
    </section>

    <section class="block">
      <div class="block-head">
        <div class="label">{t('quickWords')}</div>
        <button class="btn ghost xs" onclick={() => (editingWords = !editingWords)}>
          {editingWords ? t('done') : t('edit')}
        </button>
      </div>

      {#if !editingWords}
        {#if quickWords.length === 0}
          <div class="empty">{t('noQuickWords')}</div>
        {:else}
          <div class="chips">
            {#each quickWords as word}
              <button class="chip" onclick={() => sendQuickWord(word)}>{word}</button>
            {/each}
          </div>
        {/if}
      {:else}
        <div class="word-edit">
          {#each quickWords as word, i}
            <div class="word-row">
              <button class="btn ghost xs danger" aria-label="delete" onclick={() => removeWord(i)}>✕</button>
              <span class="word-text">{word}</span>
              <button class="btn ghost xs" aria-label="up" disabled={i === 0} onclick={() => moveWord(i, -1)}>↑</button>
              <button class="btn ghost xs" aria-label="down" disabled={i === quickWords.length - 1} onclick={() => moveWord(i, 1)}>↓</button>
            </div>
          {/each}
          <form class="add-row" onsubmit={(e) => { e.preventDefault(); addWord() }}>
            <input class="field" bind:value={newWord} placeholder={t('addWordPlaceholder')} />
            <button type="submit" class="btn sm" disabled={!newWord.trim()}>{t('add')}</button>
          </form>
        </div>
      {/if}
    </section>

    <section class="block">
      <div class="label">{t('clipboard')}</div>
      <div class="row">
        <input class="field" bind:value={clipSend} placeholder={t('clipPlaceholder')} />
        <button class="btn sm" onclick={pushPhoneClip} disabled={!clipSend}>{t('sendPhoneClip')}</button>
      </div>
      <div class="row wrap">
        <button class="btn ghost sm" onclick={getPhoneClip}>{t('getPhoneClip')}</button>
        <button class="btn ghost sm" onclick={sendToApp} disabled={!buffer}>{t('sendToApp')}</button>
      </div>
      {#if phoneClip !== null}
        <div class="clip-result">
          <div class="clip-text">{phoneClip.length ? phoneClip : t('phoneClipEmpty')}</div>
          {#if phoneClip.length}
            <button class="btn sm" onclick={() => copyText(phoneClip)}>{copiedFlag ? t('copied') : t('copyHere')}</button>
          {/if}
        </div>
      {/if}
    </section>

    <section class="block">
      <div class="label">{t('history')}</div>
      {#if history.length === 0}
        <div class="empty">{t('noHistory')}</div>
      {:else}
        <div class="chips">
          {#each history as item}
            <button class="chip" onclick={() => resend(item)}>{item.length > 28 ? item.slice(0, 28) + '…' : item}</button>
          {/each}
        </div>
      {/if}
    </section>
  {:else}
    <section class="pairing">
      <div class="lock">⌨</div>
      <p class="pair-hint">{t('enterPin')}</p>
      {#if denied}<p class="error">{t('pinWrong')}</p>{/if}
      <form onsubmit={(e) => { e.preventDefault(); submitPin() }}>
        <input class="pin" bind:value={pinInput} inputmode="numeric" placeholder={t('pinPlaceholder')} autocomplete="off" />
        <button type="submit" class="btn primary">{t('pair')}</button>
      </form>
    </section>
  {/if}

  {#if toast}<div class="toast">{toast}</div>{/if}
</main>

{#if settingsOpen}
  <div class="scrim" onclick={() => (settingsOpen = false)} role="presentation">
    <div class="sheet" onclick={(e) => e.stopPropagation()} role="dialog">
      <div class="sheet-head">
        <strong>{t('settings')}</strong>
        <button class="icon-btn" aria-label={t('dismiss')} onclick={() => (settingsOpen = false)}>✕</button>
      </div>

      <div class="label">{t('theme')}</div>
      <div class="seg">
        <button class:active={themePref === 'system'} onclick={() => persistTheme('system')}>{t('themeSystem')}</button>
        <button class:active={themePref === 'light'} onclick={() => persistTheme('light')}>{t('themeLight')}</button>
        <button class:active={themePref === 'dark'} onclick={() => persistTheme('dark')}>{t('themeDark')}</button>
      </div>

      <div class="label">{t('language')}</div>
      <select class="field" value={langPref} onchange={(e) => persistLang(e.currentTarget.value)}>
        <option value="auto">{t('langAuto')}</option>
        {#each availableLangs as l}
          <option value={l.code}>{l.label}</option>
        {/each}
      </select>

      <a
        class="btn ghost sm request-lang"
        href="https://github.com/everettjf/Remoboard/issues/new?title=Language%20request:%20"
        target="_blank"
        rel="noreferrer noopener"
      >🌐 {t('requestLang')}</a>
    </div>
  </div>
{/if}

<style>
  :global(:root) {
    --bg: #f4f4f7; --surface: #ffffff; --surface2: #ececf2;
    --text: #1a1a22; --muted: #6c6c7a; --border: #dcdce4;
    --accent: #6a5ae0; --accent-text: #ffffff; --danger: #d23b3b; --ok: #2fa37a;
  }
  :global(:root[data-theme="dark"]) {
    --bg: #0b0b0f; --surface: #15151d; --surface2: #1c1c27;
    --text: #e8e8ef; --muted: #8a8a98; --border: #2c2c3a;
    --accent: #7c6cff; --accent-text: #ffffff; --danger: #ff6b6b; --ok: #5ad19a;
  }
  :global(html, body) {
    margin: 0; height: 100%; background: var(--bg); color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    -webkit-font-smoothing: antialiased; transition: background .2s, color .2s;
  }
  :global(*) { box-sizing: border-box; }

  main {
    max-width: 760px; margin: 0 auto; padding: 16px 16px 48px;
    display: flex; flex-direction: column; gap: 14px; min-height: 100vh;
  }
  header { display: flex; align-items: center; justify-content: space-between; }
  .brand { font-size: 20px; font-weight: 700; letter-spacing: .5px; }
  .head-right { display: flex; align-items: center; gap: 12px; }
  .status { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; color: var(--muted); }
  .status .dot { width: 8px; height: 8px; border-radius: 50%; background: #e0a23a; transition: background .2s; }
  .status.ok { color: var(--ok); } .status.ok .dot { background: var(--ok); }
  .icon-btn {
    background: var(--surface2); border: 1px solid var(--border); color: var(--text);
    width: 34px; height: 34px; border-radius: 9px; font-size: 16px; cursor: pointer; line-height: 1;
  }

  .label { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: var(--muted); }
  .empty { font-size: 13px; color: var(--muted); }

  .composer { display: flex; flex-direction: column; gap: 8px; }
  .mode-row { display: inline-flex; align-self: flex-start; gap: 2px; padding: 3px; border-radius: 10px; background: var(--surface2); border: 1px solid var(--border); }
  .seg { border: none; background: transparent; color: var(--muted); padding: 5px 14px; border-radius: 8px; font-size: 13px; font-weight: 600; }
  .seg.active { background: var(--surface); color: var(--text); box-shadow: 0 1px 2px rgba(0,0,0,.15); }
  textarea {
    width: 100%; min-height: 140px; resize: vertical; background: var(--surface); color: var(--text);
    border: 1px solid var(--border); border-radius: 12px; padding: 14px; font-size: 17px; line-height: 1.5; outline: none;
  }
  textarea:focus { border-color: var(--accent); }
  .composer-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
  .composer-right { display: flex; align-items: center; gap: 10px; }
  .hint { font-size: 12px; color: var(--muted); margin-top: 8px; }
  .count { font-size: 12px; color: var(--muted); white-space: nowrap; }

  .cursor-pad { display: flex; gap: 6px; }
  .cbtn {
    min-width: 38px; height: 34px; padding: 0 8px;
    border: 1px solid var(--border); border-radius: 9px;
    background: var(--surface2); color: var(--text);
    font-size: 16px; line-height: 1; display: inline-flex; align-items: center; justify-content: center;
  }
  .cbtn:hover { border-color: var(--accent); }
  .cbtn:active { background: var(--accent); color: var(--accent-text); }

  .block { display: flex; flex-direction: column; gap: 8px; }
  .block-head { display: flex; align-items: center; justify-content: space-between; }
  .chips { display: flex; flex-wrap: wrap; gap: 8px; }

  .word-edit { display: flex; flex-direction: column; gap: 6px; }
  .word-row { display: flex; align-items: center; gap: 8px; background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 6px 10px; }
  .word-text { flex: 1; font-size: 15px; word-break: break-word; }
  .add-row { display: flex; gap: 8px; margin-top: 2px; }

  .row { display: flex; gap: 8px; align-items: center; }
  .row.wrap { flex-wrap: wrap; }
  .field {
    flex: 1; min-width: 0; background: var(--surface); color: var(--text); border: 1px solid var(--border);
    border-radius: 10px; padding: 10px 12px; font-size: 15px; outline: none;
  }
  .field:focus { border-color: var(--accent); }

  .clip-result { display: flex; align-items: center; gap: 10px; margin-top: 2px; background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 10px 12px; }
  .clip-text { flex: 1; font-size: 15px; word-break: break-word; white-space: pre-wrap; }


  button, .btn { cursor: pointer; font-family: inherit; }
  .chip {
    background: var(--surface); color: var(--text); border: 1px solid var(--border);
    border-radius: 999px; padding: 9px 15px; font-size: 15px; min-height: 40px;
  }
  .chip:active { background: var(--surface2); }
  .btn {
    background: var(--surface2); color: var(--text); border: 1px solid var(--border);
    border-radius: 9px; padding: 9px 14px; font-size: 14px; white-space: nowrap;
  }
  .btn.sm { padding: 8px 12px; font-size: 13px; }
  .btn.xs { padding: 4px 9px; font-size: 13px; border-radius: 7px; min-width: 32px; }
  .btn.ghost { background: transparent; color: var(--muted); }
  .btn.danger { color: var(--danger); }
  .btn.primary { background: var(--accent); color: var(--accent-text); border: none; font-weight: 600; }
  .btn.primary.sm { text-decoration: none; display: inline-flex; align-items: center; }
  .btn:disabled { opacity: .4; cursor: default; }

  .pairing { margin-top: 8vh; display: flex; flex-direction: column; align-items: center; gap: 14px; text-align: center; }
  .lock { font-size: 48px; }
  .pair-hint { color: var(--text); font-size: 16px; margin: 0; opacity: .85; }
  .error { color: var(--danger); font-size: 14px; margin: 0; }
  .pairing form { display: flex; gap: 10px; }
  .pin {
    background: var(--surface); color: var(--text); border: 1px solid var(--border);
    border-radius: 10px; padding: 12px 16px; font-size: 22px; letter-spacing: 6px; width: 160px; text-align: center; outline: none;
  }
  .pin:focus { border-color: var(--accent); }
  .btn.primary { padding: 12px 20px; font-size: 16px; }

  .toast {
    position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%);
    background: var(--text); color: var(--bg); padding: 10px 18px; border-radius: 999px;
    font-size: 14px; box-shadow: 0 6px 24px rgba(0,0,0,.4); z-index: 20;
  }

  .scrim { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 30; padding: 16px; }
  .sheet { width: 100%; max-width: 380px; background: var(--surface); border: 1px solid var(--border); border-radius: 16px; padding: 18px; display: flex; flex-direction: column; gap: 10px; }
  .sheet-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 4px; }
  .seg { display: flex; gap: 6px; background: var(--surface2); padding: 4px; border-radius: 10px; }
  .seg button {
    flex: 1; background: transparent; color: var(--muted); border: none; border-radius: 7px;
    padding: 8px 6px; font-size: 14px;
  }
  .seg button.active { background: var(--accent); color: var(--accent-text); font-weight: 600; }
  .request-lang { display: block; text-align: center; text-decoration: none; margin-top: 6px; color: var(--accent); border-color: var(--accent); }

  @media (max-width: 480px) {
    main { padding: 12px 12px 40px; gap: 12px; }
    .brand { font-size: 18px; }
    textarea { min-height: 120px; font-size: 16px; }
    .sheet { max-width: none; }
  }
</style>
