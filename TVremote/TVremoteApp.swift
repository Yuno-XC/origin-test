//
//  TVremoteApp.swift
//  TVremote
//
//  Android TV Remote Control App for iOS
//

import SwiftUI
import BackgroundTasks

@main
struct TVremoteApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Configure appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            #if DEBUG
            print("[TVremoteApp] Scene phase: \(oldPhase) -> \(newPhase)")
            #endif
        }
    }

    private func configureAppearance() {
        // Set dark mode as default
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        windowScene?.windows.forEach { window in
            window.overrideUserInterfaceStyle = .dark
        }
    }
}
