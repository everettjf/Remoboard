//
//  HandoffStore.swift
//  Remoboard
//
//  Handles the `remoboard://handoff?...` URL the keyboard opens:
//   - `url=<connection URL>`: publish an Apple Continuity (Handoff) web activity so the
//     same URL appears in Handoff on the user's Mac — open it there to type from the
//     computer. This is the "Handoff" button.
//   - `text=<text>`: surface text pushed from a client ("Send to phone's app").
//

import Foundation
import SwiftUI

@MainActor
final class HandoffStore: ObservableObject {
    @Published var receivedText: String?

    private var activity: NSUserActivity?

    func handle(url: URL) {
        guard url.scheme == "remoboard" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard url.host == "handoff" || components?.path.contains("handoff") == true else { return }
        let items = components?.queryItems

        if let urlString = items?.first(where: { $0.name == "url" })?.value,
           let webURL = URL(string: urlString) {
            publishHandoff(webURL)
        } else if let text = items?.first(where: { $0.name == "text" })?.value, !text.isEmpty {
            receivedText = text
        }
    }

    /// The one API the original app used: a browsing-web NSUserActivity that Continuity
    /// surfaces on the Mac.
    private func publishHandoff(_ webURL: URL) {
        activity?.invalidate()
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = webURL
        activity.becomeCurrent()
        self.activity = activity
    }
}
