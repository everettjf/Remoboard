//
//  RemoboardApp.swift
//  Remoboard
//

import SwiftUI
import UIKit
import RemoboardKit

@main
struct RemoboardApp: App {
    @StateObject private var handoff = HandoffStore()
    @Environment(\.scenePhase) private var scenePhase
    private let advertiser = BonjourAdvertiser()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(handoff)
                .onOpenURL { handoff.handle(url: $0) }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                advertiser.start(name: UIDevice.current.name, port: 7777)
            case .background, .inactive:
                advertiser.stop()
            @unknown default:
                break
            }
        }
    }
}
