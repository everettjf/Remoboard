//
//  RemoboardApp.swift
//  Remoboard
//

import SwiftUI

@main
struct RemoboardApp: App {
    @StateObject private var handoff = HandoffStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(handoff)
                .onOpenURL { handoff.handle(url: $0) }
        }
    }
}
