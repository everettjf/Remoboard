// Tiny offline i18n. The page ships inside the device, so no network lookups.
const isZh = (navigator.language || 'en').toLowerCase().startsWith('zh')

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
  clear: ['Clear (keep on phone)', '清空（保留在手机）'],
  quickWords: ['Quick words', '快捷短语'],
  noQuickWords: ['No quick words yet', '暂无快捷短语'],
  emptyHintKeys: ['When empty: Enter / arrows / Backspace control the phone cursor',
                  '输入框为空时：回车 / 方向键 / 退格 可直接操控手机光标'],
  clipboard: ['Clipboard', '剪贴板'],
  getPhoneClip: ['Pull from phone', '拉取手机剪贴板'],
  sendPhoneClip: ['Push to phone', '推送到手机'],
  clipPlaceholder: ['Text to send to phone clipboard…', '要推送到手机剪贴板的文字…'],
  copyHere: ['Copy', '复制到本机'],
  copied: ['Copied', '已复制'],
  phoneClipEmpty: ['Phone clipboard is empty', '手机剪贴板为空'],
  sendToApp: ['Send to phone’s app', '发送到手机 App'],
}

export function t(key) {
  const entry = dict[key]
  if (!entry) return key
  return isZh ? entry[1] : entry[0]
}

export const zh = isZh
