//
//  Localization.swift
//  Remoboard (macOS companion)
//
//  Inline localization for the 10 most-used App Store languages, mirroring the web client.
//  Falls back to English for any missing key.
//

import Foundation

private let activeLang: String = {
    let tag = (Locale.preferredLanguages.first ?? "en").lowercased()
    let base = String(tag.split(separator: "-").first ?? "en")
    if base == "zh" { return "zh" }
    let supported = ["en", "ja", "ko", "de", "fr", "es", "pt", "ru", "it"]
    return supported.contains(base) ? base : "en"
}()

private let tables: [String: [String: String]] = [
    "en": [
        "discover": "Devices on your network",
        "searching": "Searching… open the Remoboard app on your phone to appear here",
        "manual": "Connect manually", "host": "Phone IP", "pin": "PIN", "connect": "Connect",
        "connecting": "Connecting…", "pairing": "Pairing…", "denied": "Wrong PIN", "disconnect": "Disconnect",
        "onPhone": "On phone", "composeHint": "Type here — appears on your phone instantly",
        "clearKeep": "Clear (keep on phone)", "quickWords": "Quick words", "clipboard": "Clipboard",
        "pullClip": "Pull from phone", "pushClip": "Push to phone", "clipPlaceholder": "Send to phone clipboard…",
        "copy": "Copy", "copied": "Copied", "sendToApp": "Send to phone’s app",
        "phoneClipEmpty": "Phone clipboard is empty", "hintKeys": "⏎ newline · ⌫ delete on phone",
    ],
    "zh": [
        "discover": "局域网内的设备",
        "searching": "搜索中… 在手机上打开 Remoboard App 即可出现在这里",
        "manual": "手动连接", "host": "手机 IP", "pin": "配对码", "connect": "连接",
        "connecting": "连接中…", "pairing": "配对中…", "denied": "配对码错误", "disconnect": "断开",
        "onPhone": "手机上", "composeHint": "在这里输入，实时出现在手机上",
        "clearKeep": "清空（保留在手机）", "quickWords": "快捷短语", "clipboard": "剪贴板",
        "pullClip": "拉取手机剪贴板", "pushClip": "推送到手机", "clipPlaceholder": "推送到手机剪贴板…",
        "copy": "复制", "copied": "已复制", "sendToApp": "发送到手机 App",
        "phoneClipEmpty": "手机剪贴板为空", "hintKeys": "⏎ 换行 · ⌫ 在手机上删除",
    ],
    "ja": [
        "discover": "ネットワーク上のデバイス",
        "searching": "検索中… スマホで Remoboard App を開くとここに表示されます",
        "manual": "手動で接続", "host": "スマホのIP", "pin": "PIN", "connect": "接続",
        "connecting": "接続中…", "pairing": "ペアリング中…", "denied": "PINが違います", "disconnect": "切断",
        "onPhone": "スマホ側", "composeHint": "ここに入力すると、すぐにスマホに表示されます",
        "clearKeep": "クリア（スマホには残す）", "quickWords": "定型文", "clipboard": "クリップボード",
        "pullClip": "スマホから取得", "pushClip": "スマホへ送信", "clipPlaceholder": "スマホのクリップボードへ送信…",
        "copy": "コピー", "copied": "コピーしました", "sendToApp": "スマホのAppへ送る",
        "phoneClipEmpty": "スマホのクリップボードは空です", "hintKeys": "⏎ 改行 · ⌫ スマホで削除",
    ],
    "ko": [
        "discover": "네트워크의 기기",
        "searching": "검색 중… 휴대폰에서 Remoboard 앱을 열면 여기에 표시됩니다",
        "manual": "수동으로 연결", "host": "휴대폰 IP", "pin": "PIN", "connect": "연결",
        "connecting": "연결 중…", "pairing": "페어링 중…", "denied": "PIN 오류", "disconnect": "연결 해제",
        "onPhone": "휴대폰", "composeHint": "여기에 입력하면 휴대폰에 바로 표시됩니다",
        "clearKeep": "지우기 (휴대폰에는 유지)", "quickWords": "빠른 문구", "clipboard": "클립보드",
        "pullClip": "휴대폰에서 가져오기", "pushClip": "휴대폰으로 보내기", "clipPlaceholder": "휴대폰 클립보드로 보내기…",
        "copy": "복사", "copied": "복사됨", "sendToApp": "휴대폰 앱으로 보내기",
        "phoneClipEmpty": "휴대폰 클립보드가 비어 있습니다", "hintKeys": "⏎ 줄바꿈 · ⌫ 휴대폰에서 삭제",
    ],
    "de": [
        "discover": "Geräte im Netzwerk",
        "searching": "Suche… öffne die Remoboard-App auf dem Telefon, um hier zu erscheinen",
        "manual": "Manuell verbinden", "host": "Telefon-IP", "pin": "PIN", "connect": "Verbinden",
        "connecting": "Verbinden…", "pairing": "Koppeln…", "denied": "Falsche PIN", "disconnect": "Trennen",
        "onPhone": "Auf dem Telefon", "composeHint": "Hier tippen – erscheint sofort auf dem Telefon",
        "clearKeep": "Leeren (auf dem Telefon behalten)", "quickWords": "Schnelltexte", "clipboard": "Zwischenablage",
        "pullClip": "Vom Telefon holen", "pushClip": "Ans Telefon senden", "clipPlaceholder": "An Telefon-Zwischenablage senden…",
        "copy": "Kopieren", "copied": "Kopiert", "sendToApp": "An Telefon-App senden",
        "phoneClipEmpty": "Zwischenablage des Telefons ist leer", "hintKeys": "⏎ Zeilenumbruch · ⌫ auf dem Telefon löschen",
    ],
    "fr": [
        "discover": "Appareils sur votre réseau",
        "searching": "Recherche… ouvrez l’app Remoboard sur le téléphone pour apparaître ici",
        "manual": "Connexion manuelle", "host": "IP du téléphone", "pin": "PIN", "connect": "Connecter",
        "connecting": "Connexion…", "pairing": "Association…", "denied": "PIN incorrect", "disconnect": "Déconnecter",
        "onPhone": "Sur le téléphone", "composeHint": "Tapez ici — apparaît aussitôt sur le téléphone",
        "clearKeep": "Effacer (garder sur le téléphone)", "quickWords": "Phrases rapides", "clipboard": "Presse-papiers",
        "pullClip": "Récupérer du téléphone", "pushClip": "Envoyer au téléphone", "clipPlaceholder": "Envoyer au presse-papiers du téléphone…",
        "copy": "Copier", "copied": "Copié", "sendToApp": "Envoyer à l’app du téléphone",
        "phoneClipEmpty": "Le presse-papiers du téléphone est vide", "hintKeys": "⏎ nouvelle ligne · ⌫ supprimer sur le téléphone",
    ],
    "es": [
        "discover": "Dispositivos en tu red",
        "searching": "Buscando… abre la app Remoboard en el teléfono para aparecer aquí",
        "manual": "Conectar manualmente", "host": "IP del teléfono", "pin": "PIN", "connect": "Conectar",
        "connecting": "Conectando…", "pairing": "Emparejando…", "denied": "PIN incorrecto", "disconnect": "Desconectar",
        "onPhone": "En el teléfono", "composeHint": "Escribe aquí: aparece al instante en el teléfono",
        "clearKeep": "Borrar (mantener en el teléfono)", "quickWords": "Frases rápidas", "clipboard": "Portapapeles",
        "pullClip": "Traer del teléfono", "pushClip": "Enviar al teléfono", "clipPlaceholder": "Enviar al portapapeles del teléfono…",
        "copy": "Copiar", "copied": "Copiado", "sendToApp": "Enviar a la app del teléfono",
        "phoneClipEmpty": "El portapapeles del teléfono está vacío", "hintKeys": "⏎ nueva línea · ⌫ borrar en el teléfono",
    ],
    "pt": [
        "discover": "Dispositivos na sua rede",
        "searching": "Procurando… abra o app Remoboard no telefone para aparecer aqui",
        "manual": "Conectar manualmente", "host": "IP do telefone", "pin": "PIN", "connect": "Conectar",
        "connecting": "Conectando…", "pairing": "Pareando…", "denied": "PIN incorreto", "disconnect": "Desconectar",
        "onPhone": "No telefone", "composeHint": "Digite aqui — aparece no telefone na hora",
        "clearKeep": "Limpar (manter no telefone)", "quickWords": "Frases rápidas", "clipboard": "Área de transferência",
        "pullClip": "Puxar do telefone", "pushClip": "Enviar ao telefone", "clipPlaceholder": "Enviar à área de transferência do telefone…",
        "copy": "Copiar", "copied": "Copiado", "sendToApp": "Enviar ao app do telefone",
        "phoneClipEmpty": "A área de transferência do telefone está vazia", "hintKeys": "⏎ nova linha · ⌫ apagar no telefone",
    ],
    "ru": [
        "discover": "Устройства в сети",
        "searching": "Поиск… откройте приложение Remoboard на телефоне, чтобы появиться здесь",
        "manual": "Подключить вручную", "host": "IP телефона", "pin": "PIN", "connect": "Подключить",
        "connecting": "Подключение…", "pairing": "Сопряжение…", "denied": "Неверный PIN", "disconnect": "Отключить",
        "onPhone": "На телефоне", "composeHint": "Печатайте здесь — мгновенно появится на телефоне",
        "clearKeep": "Очистить (оставить на телефоне)", "quickWords": "Быстрые фразы", "clipboard": "Буфер обмена",
        "pullClip": "Получить с телефона", "pushClip": "Отправить на телефон", "clipPlaceholder": "Отправить в буфер обмена телефона…",
        "copy": "Копировать", "copied": "Скопировано", "sendToApp": "Отправить в приложение телефона",
        "phoneClipEmpty": "Буфер обмена телефона пуст", "hintKeys": "⏎ новая строка · ⌫ удалить на телефоне",
    ],
    "it": [
        "discover": "Dispositivi sulla rete",
        "searching": "Ricerca… apri l’app Remoboard sul telefono per apparire qui",
        "manual": "Connetti manualmente", "host": "IP del telefono", "pin": "PIN", "connect": "Connetti",
        "connecting": "Connessione…", "pairing": "Abbinamento…", "denied": "PIN errato", "disconnect": "Disconnetti",
        "onPhone": "Sul telefono", "composeHint": "Scrivi qui: appare subito sul telefono",
        "clearKeep": "Cancella (mantieni sul telefono)", "quickWords": "Frasi rapide", "clipboard": "Appunti",
        "pullClip": "Prendi dal telefono", "pushClip": "Invia al telefono", "clipPlaceholder": "Invia agli appunti del telefono…",
        "copy": "Copia", "copied": "Copiato", "sendToApp": "Invia all’app del telefono",
        "phoneClipEmpty": "Gli appunti del telefono sono vuoti", "hintKeys": "⏎ a capo · ⌫ elimina sul telefono",
    ],
]

func t(_ key: String) -> String {
    if key == "title" { return "Remoboard" }
    return tables[activeLang]?[key] ?? tables["en"]?[key] ?? key
}
