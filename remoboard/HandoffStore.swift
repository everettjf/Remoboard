//
//  HandoffStore.swift
//  Remoboard
//
//  Receives text handed off from the keyboard extension via the `remoboard://` URL
//  scheme and exposes it to the UI.
//

import Foundation
import SwiftUI

@MainActor
final class HandoffStore: ObservableObject {
    @Published var receivedText: String?

    func handle(url: URL) {
        guard url.scheme == "remoboard" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard url.host == "handoff" || components?.path.contains("handoff") == true else { return }
        let text = components?.queryItems?.first(where: { $0.name == "text" })?.value
        if let text, !text.isEmpty {
            receivedText = text
        }
    }
}
