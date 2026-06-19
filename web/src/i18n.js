// Offline bilingual strings. The page ships inside the device, so no network lookups.
// Language can be auto (from the browser), or forced to en / zh by the user.

const dict = {
  title: ['Remoboard', 'Remoboard'],
  connecting: ['Connecting…', '连接中…'],
  reconnecting: ['Reconnecting…', '重新连接中…'],
  connected: ['Connected', '已连接'],
  enterPin: ['Enter the PIN shown on your phone', '请输入手机上显示的配对码'],
  pinPlaceholder: ['PIN', '配对码'],
  pair: ['Pair', '配对'],
  pinWrong: ['Wrong PIN, try again', '配对码错误，请重试'],
  composeHint: ['Type here — text appears on your phone instantly', '在这里输入，文字会实时出现在手机上'],
  onPhone: ['On phone', '手机上'],
  clear: ['Clear', '清空'],
  clearHint: ['Clears here, keeps the text on your phone', '只清空这里，手机上的文字保留'],
  chars: ['chars', '字'],
  quickWords: ['Quick words', '快捷短语'],
  noQuickWords: ['No quick words yet', '暂无快捷短语'],
  emptyHintKeys: ['When empty: Enter / arrows / Backspace control the phone cursor',
                  '输入框为空时：回车 / 方向键 / 退格 可直接操控手机光标'],
  edit: ['Edit', '编辑'],
  done: ['Done', '完成'],
  addWordPlaceholder: ['Add a quick word…', '添加快捷短语…'],
  add: ['Add', '添加'],
  clipboard: ['Clipboard', '剪贴板'],
  getPhoneClip: ['Pull from phone', '拉取手机剪贴板'],
  sendPhoneClip: ['Push to phone', '推送到手机'],
  clipPlaceholder: ['Text to send to phone clipboard…', '要推送到手机剪贴板的文字…'],
  copyHere: ['Copy', '复制到本机'],
  copied: ['Copied', '已复制'],
  phoneClipEmpty: ['Phone clipboard is empty', '手机剪贴板为空'],
  sendToApp: ['Send to phone’s app', '发送到手机 App'],
  history: ['Recent', '最近发送'],
  noHistory: ['Messages you clear show up here to resend', '清空过的消息会显示在这里，可一键重发'],
  receivedFromPhone: ['Received from phone', '来自手机'],
  openLink: ['Open link', '打开链接'],
  dismiss: ['Dismiss', '关闭'],
  settings: ['Settings', '设置'],
  theme: ['Appearance', '外观'],
  themeSystem: ['System', '跟随系统'],
  themeLight: ['Light', '浅色'],
  themeDark: ['Dark', '深色'],
  language: ['Language', '语言'],
  langAuto: ['Auto', '自动'],
  langEn: ['English', 'English'],
  langZh: ['中文', '中文'],
}

export function detectLang() {
  return (navigator.language || 'en').toLowerCase().startsWith('zh') ? 'zh' : 'en'
}

export function translate(key, lang) {
  const entry = dict[key]
  if (!entry) return key
  return lang === 'zh' ? entry[1] : entry[0]
}
