<script>
  import { onMount } from 'svelte'
  import { Connection } from './connection.js'
  import { translate, detectLang, availableLangs } from './i18n.js'
  import { loadThemePref, saveThemePref, applyTheme, watchSystem } from './theme.js'

  // ---- settings (persisted) ----
  let themePref = $state(loadThemePref())                                  // system | light | dark
  let langPref = $state(localStorage.getItem('rkb-lang') || 'auto')        // auto | en | zh
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
  let phoneBefore = $state('')
  let phoneAfter = $state('')
  let textarea = $state(null)

  // ---- features ----
  let quickWords = $state([])
  let editingWords = $state(false)
  let newWord = $state('')
  let phoneClip = $state(null)
  let clipSend = $state('')
  let copiedFlag = $state(false)
  let history = $state([])
  let received = $state(null)        // { text, url } handoff from phone
  let toast = $state('')

  // ---- non-reactive ----
  let conn
  let seq = 0
  let lastSent = ''
  let composing = false
  let toastTimer

  // ---- theme application ----
  $effect(() => { applyTheme(themePref) })
  onMount(() => watchSystem(() => { if (themePref === 'system') applyTheme(themePref) }))

  onMount(() => {
    conn = new Connection({
      onState: (s) => {
        socketState = s
        if (s === 'reconnecting' && phase === 'paired') phase = 'reconnecting'
        if (s === 'open' && phase === 'connecting') phase = 'pairing'
      },
      onMessage: (msg) => handleMessage(msg),
    })
    conn.connect()
    return () => conn.close()
  })

  function persistTheme(p) { themePref = p; saveThemePref(p) }
  function persistLang(l) { langPref = l; localStorage.setItem('rkb-lang', l) }

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
      case 'open':
        handleHandoff(msg.text ?? '')
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

  // ---- live diff send (compare by codepoints so emoji never split) ----
  function sendDiff(oldStr, newStr) {
    const a = Array.from(oldStr)
    const b = Array.from(newStr)
    let p = 0
    const min = Math.min(a.length, b.length)
    while (p < min && a[p] === b[p]) p++
    const deletions = a.length - p
    const insertion = b.slice(p).join('')
    let ok = true
    for (let i = 0; i < deletions; i++) ok = gatedSend({ t: 'delete', seq: seq++ }) && ok
    if (insertion.length) ok = gatedSend({ t: 'input', text: insertion, seq: seq++ }) && ok
    return ok
  }

  function syncBuffer() {
    if (composing || phase !== 'paired') return
    if (sendDiff(lastSent, buffer)) lastSent = buffer
  }

  function onInput() { if (!composing) syncBuffer() }
  function onCompositionStart() { composing = true }
  function onCompositionEnd() { composing = false; syncBuffer() }

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

  function clearBuffer() {
    const snip = buffer.trim()
    if (snip) history = [snip, ...history.filter((h) => h !== snip)].slice(0, 12)
    buffer = ''
    lastSent = ''
    textarea && textarea.focus()
  }

  function resend(text) {
    gatedSend({ t: 'input', text, seq: seq++ })
  }

  function sendQuickWord(word) { gatedSend({ t: 'input', text: word, seq: seq++ }) }

  // ---- quick words management (synced to phone) ----
  function pushWords(words) {
    quickWords = words
    gatedSend({ t: 'words-set', items: words })
  }
  function addWord() {
    const w = newWord.trim()
    if (!w) return
    pushWords([...quickWords, w])
    newWord = ''
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

  // ---- handoff received from phone ----
  function toURL(s) {
    const v = (s || '').trim()
    if (/^[a-z][a-z0-9+.-]*:\/\//i.test(v)) return v
    if (/^[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(v) && !/\s/.test(v)) return 'https://' + v
    return null
  }
  function handleHandoff(text) {
    if (!text.trim()) return
    received = { text, url: toURL(text) }
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

  {#if received}
    <section class="handoff">
      <div class="handoff-label">{t('receivedFromPhone')}</div>
      <div class="handoff-body">{received.text}</div>
      <div class="handoff-actions">
        {#if received.url}
          <a class="btn primary sm" href={received.url} target="_blank" rel="noreferrer noopener">{t('openLink')}</a>
        {/if}
        <button class="btn sm" onclick={() => copyText(received.text)}>{copiedFlag ? t('copied') : t('copyHere')}</button>
        <button class="btn ghost sm" onclick={() => (received = null)}>{t('dismiss')}</button>
      </div>
    </section>
  {/if}

  {#if phase === 'paired' || phase === 'reconnecting'}
    <section class="echo">
      <div class="label">{t('onPhone')}</div>
      <div class="echo-body">
        <span>{phoneBefore}</span><span class="caret"></span><span class="dim">{phoneAfter}</span>
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
        autocapitalize="off" autocomplete="off" autocorrect="off" spellcheck="false"
      ></textarea>
      <div class="composer-row">
        <div class="hint">{t('emptyHintKeys')}</div>
        <div class="composer-right">
          <span class="count">{Array.from(buffer).length} {t('chars')}</span>
          <button class="btn ghost sm" title={t('clearHint')} onclick={clearBuffer}>{t('clear')}</button>
        </div>
      </div>
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

  .echo { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 10px 12px; }
  .echo-body { font-size: 15px; line-height: 1.5; min-height: 22px; word-break: break-word; white-space: pre-wrap; margin-top: 4px; }
  .dim { color: var(--muted); }
  .caret { display: inline-block; width: 2px; height: 1.1em; vertical-align: text-bottom; background: var(--accent); margin: 0 1px; animation: blink 1s steps(1) infinite; }
  @keyframes blink { 50% { opacity: 0; } }

  .composer { display: flex; flex-direction: column; gap: 8px; }
  textarea {
    width: 100%; min-height: 140px; resize: vertical; background: var(--surface); color: var(--text);
    border: 1px solid var(--border); border-radius: 12px; padding: 14px; font-size: 17px; line-height: 1.5; outline: none;
  }
  textarea:focus { border-color: var(--accent); }
  .composer-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
  .composer-right { display: flex; align-items: center; gap: 10px; }
  .hint { font-size: 12px; color: var(--muted); flex: 1; min-width: 160px; }
  .count { font-size: 12px; color: var(--muted); white-space: nowrap; }

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

  .handoff { background: var(--surface); border: 1px solid var(--accent); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; gap: 8px; }
  .handoff-label { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: var(--accent); }
  .handoff-body { font-size: 15px; word-break: break-word; }
  .handoff-actions { display: flex; flex-wrap: wrap; gap: 8px; }

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

  @media (max-width: 480px) {
    main { padding: 12px 12px 40px; gap: 12px; }
    .brand { font-size: 18px; }
    textarea { min-height: 120px; font-size: 16px; }
    .sheet { max-width: none; }
  }
</style>
