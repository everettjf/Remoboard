//
//  Localization.swift
//  Remoboard (macOS companion)
//
//  Compact inline bilingual strings (en / zh), mirroring the web client.
//

import Foundation

private let isZh = (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("zh")

private let strings: [String: (String, String)] = [
    "title": ("Remoboard", "Remoboard"),
    "discover": ("Devices on your network", "局域网内的设备"),
    "searching": ("Searching… open the Remoboard app on your phone to appear here",
                  "搜索中… 在手机上打开 Remoboard App 即可出现在这里"),
    "manual": ("Connect manually", "手动连接"),
    "host": ("Phone IP", "手机 IP"),
    "pin": ("PIN", "配对码"),
    "connect": ("Connect", "连接"),
    "connecting": ("Connecting…", "连接中…"),
    "pairing": ("Pairing…", "配对中…"),
    "denied": ("Wrong PIN", "配对码错误"),
    "disconnect": ("Disconnect", "断开"),
    "onPhone": ("On phone", "手机上"),
    "composeHint": ("Type here — appears on your phone instantly", "在这里输入，实时出现在手机上"),
    "clearKeep": ("Clear (keep on phone)", "清空（保留在手机）"),
    "quickWords": ("Quick words", "快捷短语"),
    "clipboard": ("Clipboard", "剪贴板"),
    "pullClip": ("Pull from phone", "拉取手机剪贴板"),
    "pushClip": ("Push to phone", "推送到手机"),
    "clipPlaceholder": ("Send to phone clipboard…", "推送到手机剪贴板…"),
    "copy": ("Copy", "复制"),
    "copied": ("Copied", "已复制"),
    "sendToApp": ("Send to phone’s app", "发送到手机 App"),
    "phoneClipEmpty": ("Phone clipboard is empty", "手机剪贴板为空"),
    "hintKeys": ("⏎ newline · ⌫ delete on phone", "⏎ 换行 · ⌫ 在手机上删除"),
]

func t(_ key: String) -> String {
    guard let pair = strings[key] else { return key }
    return isZh ? pair.1 : pair.0
}
