// Appearance: follow the system by default, or force light/dark. Persisted locally.
const KEY = 'rkb-theme'
const mq = () => window.matchMedia('(prefers-color-scheme: dark)')

export function loadThemePref() {
  // localStorage can throw in private mode / sandboxed contexts — fall back to system.
  try {
    const v = localStorage.getItem(KEY)
    return v === 'light' || v === 'dark' ? v : 'system'
  } catch { return 'system' }
}

export function saveThemePref(pref) {
  try { localStorage.setItem(KEY, pref) } catch {}
}

export function effectiveTheme(pref) {
  if (pref === 'light' || pref === 'dark') return pref
  return mq().matches ? 'dark' : 'light'
}

export function applyTheme(pref) {
  document.documentElement.dataset.theme = effectiveTheme(pref)
}

// Re-apply when the system scheme changes (only matters while pref === 'system').
export function watchSystem(onChange) {
  const m = mq()
  m.addEventListener('change', onChange)
  return () => m.removeEventListener('change', onChange)
}
