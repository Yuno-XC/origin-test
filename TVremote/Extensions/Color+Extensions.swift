//
//  Color+Extensions.swift
//  TVremote
//
//  Color utilities
//

import SwiftUI

extension Color {
    static let remoteBackground = Color.black
    static let remoteGray = Color(.systemGray6)
    static let remoteLightGray = Color(.systemGray5)
    static let remoteAccent = Color.blue
}

extension View {
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
