//
//  TVremoteApp.swift
//  TVremote
//
//  Android TV Remote Control App for iOS
//

import SwiftUI

@main
struct TVremoteApp: App {
    init() {
        // Configure appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
