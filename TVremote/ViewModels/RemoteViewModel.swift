//
//  RemoteViewModel.swift
//  TVremote
//
//  Remote control view model
//

import Foundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class RemoteViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var showKeyboard = false
    @Published var keyboardText = ""
    @Published private(set) var isTypingMode = false

    // MARK: - Services

    private let adapter: AndroidTVAdapter
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Long Press State

    private var longPressAction: RemoteAction?
    private var longPressTask: Task<Void, Never>?

    // MARK: - Initialization

    init(adapter: AndroidTVAdapter) {
        self.adapter = adapter
        feedbackGenerator.prepare()
        lightFeedback.prepare()
    }

    // MARK: - Remote Actions

    func sendAction(_ action: RemoteAction) {
        #if DEBUG
        print("[RemoteViewModel] 🔘 Button pressed: \(action)")
        #endif
        hapticFeedback()
        Task {
            do {
                try await adapter.send(action)
                #if DEBUG
                print("[RemoteViewModel] ✅ Action sent successfully: \(action)")
                #endif
            } catch {
                #if DEBUG
                print("[RemoteViewModel] ❌ Failed to send action \(action): \(error)")
                #endif
            }
        }
    }

    func startLongPress(_ action: RemoteAction) {
        guard action.requiresLongPress else {
            sendAction(action)
            return
        }

        #if DEBUG
        print("[RemoteViewModel] 🔘 Long press started: \(action)")
        #endif
        longPressAction = action
        hapticFeedback()

        Task {
            do {
                try await adapter.send(action, direction: .startLong)
                #if DEBUG
                print("[RemoteViewModel] ✅ Long press start sent: \(action)")
                #endif
            } catch {
                #if DEBUG
                print("[RemoteViewModel] ❌ Failed to send long press start \(action): \(error)")
                #endif
            }
        }

        // Repeat haptic while held - throttled to avoid performance impact
        longPressTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 350_000_000) // 350ms between haptics
                if Task.isCancelled { break }
                lightHaptic()
            }
        }
    }

    func endLongPress(_ action: RemoteAction) {
        #if DEBUG
        print("[RemoteViewModel] 🔘 Long press ended: \(action)")
        #endif
        longPressTask?.cancel()
        longPressTask = nil

        if longPressAction == action {
            Task {
                do {
                    try await adapter.send(action, direction: .endLong)
                    #if DEBUG
                    print("[RemoteViewModel] ✅ Long press end sent: \(action)")
                    #endif
                } catch {
                    #if DEBUG
                    print("[RemoteViewModel] ❌ Failed to send long press end \(action): \(error)")
                    #endif
                }
            }
            longPressAction = nil
        }
    }

    // MARK: - Navigation

    func dpadUp() { 
        #if DEBUG
        print("[RemoteViewModel] ⬆️ D-Pad UP pressed")
        #endif
        sendAction(.dpadUp) 
    }
    func dpadDown() { 
        #if DEBUG
        print("[RemoteViewModel] ⬇️ D-Pad DOWN pressed")
        #endif
        sendAction(.dpadDown) 
    }
    func dpadLeft() { 
        #if DEBUG
        print("[RemoteViewModel] ⬅️ D-Pad LEFT pressed")
        #endif
        sendAction(.dpadLeft) 
    }
    func dpadRight() { 
        #if DEBUG
        print("[RemoteViewModel] ➡️ D-Pad RIGHT pressed")
        #endif
        sendAction(.dpadRight) 
    }
    func dpadCenter() { 
        #if DEBUG
        print("[RemoteViewModel] ⭕ D-Pad CENTER pressed")
        #endif
        sendAction(.dpadCenter) 
    }

    // MARK: - System

    func home() { 
        #if DEBUG
        print("[RemoteViewModel] 🏠 HOME pressed")
        #endif
        sendAction(.home) 
    }
    func back() { 
        #if DEBUG
        print("[RemoteViewModel] ⬅️ BACK pressed")
        #endif
        sendAction(.back) 
    }
    func menu() { 
        #if DEBUG
        print("[RemoteViewModel] ☰ MENU pressed")
        #endif
        sendAction(.menu) 
    }

    // MARK: - Media

    func playPause() { 
        #if DEBUG
        print("[RemoteViewModel] ⏯️ PLAY/PAUSE pressed")
        #endif
        sendAction(.playPause) 
    }
    func rewind() { 
        #if DEBUG
        print("[RemoteViewModel] ⏪ REWIND started")
        #endif
        startLongPress(.rewind) 
    }
    func fastForward() { 
        #if DEBUG
        print("[RemoteViewModel] ⏩ FAST FORWARD started")
        #endif
        startLongPress(.fastForward) 
    }
    func stopRewind() { 
        #if DEBUG
        print("[RemoteViewModel] ⏪ REWIND stopped")
        #endif
        endLongPress(.rewind) 
    }
    func stopFastForward() { 
        #if DEBUG
        print("[RemoteViewModel] ⏩ FAST FORWARD stopped")
        #endif
        endLongPress(.fastForward) 
    }
    func previous() { 
        #if DEBUG
        print("[RemoteViewModel] ⏮️ PREVIOUS pressed")
        #endif
        sendAction(.previous) 
    }
    func next() { 
        #if DEBUG
        print("[RemoteViewModel] ⏭️ NEXT pressed")
        #endif
        sendAction(.next) 
    }

    // MARK: - Volume

    func volumeUp() { 
        #if DEBUG
        print("[RemoteViewModel] 🔊 VOLUME UP pressed")
        #endif
        sendAction(.volumeUp) 
    }
    func volumeDown() { 
        #if DEBUG
        print("[RemoteViewModel] 🔉 VOLUME DOWN pressed")
        #endif
        sendAction(.volumeDown) 
    }
    func mute() { 
        #if DEBUG
        print("[RemoteViewModel] 🔇 MUTE pressed")
        #endif
        sendAction(.mute) 
    }

    // MARK: - Power

    func power() { 
        #if DEBUG
        print("[RemoteViewModel] ⚡ POWER pressed")
        #endif
        sendAction(.power) 
    }

    // MARK: - Text Input

    func openKeyboard() {
        showKeyboard = true
        isTypingMode = true
        keyboardText = ""
    }

    func closeKeyboard() {
        showKeyboard = false
        isTypingMode = false
    }

    func sendText(_ text: String) {
        guard !text.isEmpty else { return }

        hapticFeedback()
        Task {
            try? await adapter.send(.textInput(text))
        }
    }

    func sendCharacter(_ char: String) {
        guard !char.isEmpty else { return }

        #if DEBUG
        print("[RemoteViewModel] 📝 Sending text: '\(char)'")
        #endif
        
        hapticFeedback()
        Task {
            try? await adapter.send(.textInput(char))
        }
    }

    func deleteCharacter() {
        lightHaptic()
        Task {
            try? await adapter.send(.deleteCharacter)
        }
    }

    func sendEnter() {
        hapticFeedback()
        Task {
            try? await adapter.send(.enter)
        }
    }

    // MARK: - Haptic Feedback

    private func hapticFeedback() {
        feedbackGenerator.impactOccurred()
    }

    private func lightHaptic() {
        lightFeedback.impactOccurred()
    }
}
