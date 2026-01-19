//
//  RemoteAction.swift
//  TVremote
//
//  High-level remote control actions
//

import Foundation

/// High-level remote actions that the UI can emit
/// These are platform-agnostic and get translated by the adapter
enum RemoteAction: Equatable {
    // Navigation
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case dpadCenter

    // System
    case home
    case back
    case menu

    // Media
    case playPause
    case play
    case pause
    case stop
    case next
    case previous
    case rewind
    case fastForward

    // Volume
    case volumeUp
    case volumeDown
    case mute

    // Power
    case power

    // Text input
    case textInput(String)
    case deleteCharacter
    case enter

    // App launching
    case openApp(String) // deep link URL

    var requiresLongPress: Bool {
        switch self {
        case .rewind, .fastForward:
            return true
        default:
            return false
        }
    }
}

/// Key press direction for long press support
enum KeyPressDirection {
    case short
    case startLong
    case endLong
}
