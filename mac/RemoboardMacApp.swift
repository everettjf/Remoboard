//
//  RemoboardMacApp.swift
//  Remoboard (macOS companion)
//
//  A menu-bar app that types into your phone over the same protocol as the browser UI.
//

import SwiftUI

@main
struct RemoboardMacApp: App {
    @StateObject private var client = MacClient()
    @StateObject private var discovery = Discovery()

    var body: some Scene {
        MenuBarExtra("Remoboard", systemImage: "keyboard.badge.ellipsis") {
            PopoverView(client: client, discovery: discovery)
                .frame(width: 360)
        }
        .menuBarExtraStyle(.window)
    }
}
