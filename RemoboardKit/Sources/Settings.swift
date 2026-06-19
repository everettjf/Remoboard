//
//  Settings.swift
//  RemoboardKit
//
//  App-group backed settings shared between the host app and the keyboard extension.
//  Replaces the legacy Objective-C `KBSetting` singleton.
//

import Foundation

public enum ConnectMode: Int {
    case http = 0
    // BLE (legacy value 2) intentionally dropped in the Swift rewrite.
}

public final class Settings {

    public static let appGroup = "group.everettjf.remoboard"
    public static let shared = Settings()

    private let defaults: UserDefaults

    private enum Key {
        static let words = "rkb.quickWords"
        static let connectMode = "rkb.connectMode"
        static let lastAppVersion = "rkb.lastAppVersion"
    }

    private init() {
        defaults = UserDefaults(suiteName: Settings.appGroup) ?? .standard
    }

    // MARK: - Quick words

    public static let defaultWords = [
        "OK", "Thanks!", "On my way", "Got it", "👍",
        "好的", "收到", "稍等",
    ]

    public var quickWords: [String] {
        get { defaults.stringArray(forKey: Key.words) ?? Settings.defaultWords }
        set { defaults.set(newValue, forKey: Key.words) }
    }

    public func addWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var words = quickWords
        words.append(trimmed)
        quickWords = words
    }

    public func updateWord(at index: Int, to word: String) {
        var words = quickWords
        guard words.indices.contains(index) else { return }
        words[index] = word
        quickWords = words
    }

    public func removeWord(at index: Int) {
        var words = quickWords
        guard words.indices.contains(index) else { return }
        words.remove(at: index)
        quickWords = words
    }

    public func resetDefaultWords() {
        quickWords = Settings.defaultWords
    }

    // MARK: - Connection mode

    public var connectMode: ConnectMode {
        get { ConnectMode(rawValue: defaults.integer(forKey: Key.connectMode)) ?? .http }
        set { defaults.set(newValue.rawValue, forKey: Key.connectMode) }
    }

    // MARK: - Misc

    public var lastAppVersion: String? {
        get { defaults.string(forKey: Key.lastAppVersion) }
        set { defaults.set(newValue, forKey: Key.lastAppVersion) }
    }
}
