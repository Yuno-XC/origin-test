//
//  ConnectionState.swift
//  TVremote
//
//  Connection state definitions
//

import Foundation

/// Represents the current state of the TV connection
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case pairing(PairingState)
    case connected
    case error(ConnectionError)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .disconnected:
            return "Not Connected"
        case .connecting:
            return "Connecting..."
        case .pairing(let state):
            return state.displayText
        case .connected:
            return "Connected"
        case .error(let error):
            return error.localizedDescription
        }
    }
}

/// Pairing workflow states
enum PairingState: Equatable {
    case starting
    case waitingForCode
    case validatingCode
    case success
    case failed(String)

    var displayText: String {
        switch self {
        case .starting:
            return "Starting pairing..."
        case .waitingForCode:
            return "Enter code shown on TV"
        case .validatingCode:
            return "Validating..."
        case .success:
            return "Paired successfully"
        case .failed(let reason):
            return "Pairing failed: \(reason)"
        }
    }
}

/// Connection errors with recovery hints
enum ConnectionError: Error, Equatable {
    case networkUnavailable
    case deviceUnreachable
    case pairingRequired
    case pairingFailed(String)
    case connectionLost
    case timeout
    case certificateError
    case unknown(String)

    var localizedDescription: String {
        switch self {
        case .networkUnavailable:
            return "Network unavailable"
        case .deviceUnreachable:
            return "TV not reachable"
        case .pairingRequired:
            return "Pairing required"
        case .pairingFailed(let reason):
            return "Pairing failed: \(reason)"
        case .connectionLost:
            return "Connection lost"
        case .timeout:
            return "Connection timed out"
        case .certificateError:
            return "Security error"
        case .unknown(let message):
            return message
        }
    }

    var recoveryHint: String {
        switch self {
        case .networkUnavailable:
            return "Check your Wi-Fi connection"
        case .deviceUnreachable:
            return "Ensure TV is on and on the same network"
        case .pairingRequired, .pairingFailed:
            return "Try pairing again"
        case .connectionLost:
            return "Tap to reconnect"
        case .timeout:
            return "Check if TV is powered on"
        case .certificateError:
            return "Reset pairing and try again"
        case .unknown:
            return "Try again"
        }
    }
}
