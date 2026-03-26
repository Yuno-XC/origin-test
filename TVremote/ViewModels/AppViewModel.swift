//
//  AppViewModel.swift
//  TVremote
//
//  Main app state management
//

import Foundation
import Combine
import SwiftUI

/// Main app state and navigation
@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Navigation State

    enum NavigationState: Equatable {
        case discovery
        case pairing(TVDevice)
        case remote(TVDevice)
    }

    // MARK: - Published Properties

    @Published private(set) var navigationState: NavigationState = .discovery
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var connectedDevice: TVDevice?

    // MARK: - Services

    let adapter: any TVRemoteAdapterProtocol
    private let persistence: PersistenceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 3

    // MARK: - Initialization

    init(
        adapter: any TVRemoteAdapterProtocol = AndroidTVAdapter(),
        persistence: PersistenceProtocol = PersistenceService.shared
    ) {
        self.adapter = adapter
        self.persistence = persistence
        setupBindings()
        checkLastConnectedDevice()
    }

    private func setupBindings() {
        adapter.connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                self?.handleConnectionStateChange(state)
            }
            .store(in: &cancellables)
    }

    private func checkLastConnectedDevice() {
        if let lastDevice = persistence.getLastConnectedDevice(), lastDevice.isPaired {
            // Auto-connect to last device
            Task {
                await connect(to: lastDevice)
            }
        }
    }

    // MARK: - Navigation

    func showDiscovery() {
        navigationState = .discovery
    }

    func showPairing(for device: TVDevice) {
        navigationState = .pairing(device)
    }

    func showRemote(for device: TVDevice) {
        navigationState = .remote(device)
    }

    // MARK: - Connection Management

    func connect(to device: TVDevice) async {
        #if DEBUG
        print("[AppViewModel] 🔌 connect() called for device: \(device.name), isPaired: \(device.isPaired)")
        #endif
        
        do {
            if device.isPaired {
                connectionState = .connecting
                try await adapter.connect(to: device)
                
                #if DEBUG
                print("[AppViewModel] ✅ connect() completed successfully")
                #endif
                
                connectedDevice = device
                persistence.setLastConnectedDevice(device)
                navigationState = .remote(device)
            } else {
                showPairing(for: device)
            }
        } catch {
            #if DEBUG
            print("[AppViewModel] ❌ connect() failed: \(error)")
            #endif
            connectionState = .error(.deviceUnreachable)
        }
    }

    func disconnect() {
        cancelReconnect()
        adapter.disconnect()
        connectedDevice = nil
        navigationState = .discovery
    }

    func startPairing(for device: TVDevice) async {
        #if DEBUG
        print("[AppViewModel] Starting pairing for device: \(device.name) at \(device.host)")
        #endif
        
        do {
            try await adapter.startPairing(to: device)
            #if DEBUG
            print("[AppViewModel] Pairing started successfully")
            #endif
        } catch {
            #if DEBUG
            print("[AppViewModel] Pairing failed: \(error.localizedDescription)")
            #endif
            connectionState = .error(.pairingFailed(error.localizedDescription))
        }
    }

    func submitPairingCode(_ code: String) async {
        guard case .pairing(let device) = navigationState else { return }

        do {
            try await adapter.submitPairingCode(code)

            // Mark device as paired and save
            var pairedDevice = device
            pairedDevice.isPaired = true
            persistence.saveDevice(pairedDevice)

            #if DEBUG
            print("[AppViewModel] Pairing code submitted, device: \(pairedDevice.name)")
            print("[AppViewModel] Adapter currentDevice before connect: \(adapter.currentDevice?.name ?? "nil")")
            #endif

            // Connect to the device - this will set currentDevice in adapter
            await connect(to: pairedDevice)
            
            #if DEBUG
            print("[AppViewModel] After connect, adapter currentDevice: \(adapter.currentDevice?.name ?? "nil")")
            #endif
        } catch {
            connectionState = .error(.pairingFailed(error.localizedDescription))
        }
    }

    func cancelPairing() {
        cancelReconnect()
        adapter.disconnect()
        navigationState = .discovery
    }

    func skipPairingAndConnect(device: TVDevice) {
        // Mark device as paired and try to connect directly
        var pairedDevice = device
        pairedDevice.isPaired = true
        persistence.saveDevice(pairedDevice)

        cancelReconnect()
        adapter.disconnect()

        Task {
            await connect(to: pairedDevice)
        }
    }

    // MARK: - Remote Actions

    func send(_ action: RemoteAction) async {
        do {
            try await adapter.send(action)
        } catch {
            // Silent failure for remote commands - UI provides haptic feedback
        }
    }

    func send(_ action: RemoteAction, direction: KeyPressDirection) async {
        do {
            try await adapter.send(action, direction: direction)
        } catch {
            // Silent failure
        }
    }

    // MARK: - Private

    private func handleConnectionStateChange(_ state: ConnectionState) {
        switch state {
        case .connected:
            cancelReconnect()
            if let device = adapter.currentDevice {
                connectedDevice = device
            }

        case .disconnected:
            if navigationState != .discovery {
                // Connection was lost unexpectedly
                // Keep on remote view but show disconnected state
            }

        case .error(let error):
            if case .connectionLost = error {
                scheduleReconnectIfNeeded()
            }

        default:
            break
        }
    }

    private func scheduleReconnectIfNeeded() {
        guard reconnectTask == nil else {
            #if DEBUG
            print("[AppViewModel] Reconnect already scheduled; skipping duplicate request")
            #endif
            return
        }

        guard let device = connectedDevice else {
            #if DEBUG
            print("[AppViewModel] No connected device available for reconnect")
            #endif
            return
        }

        reconnectTask = Task { [weak self] in
            guard let self else { return }
            defer { self.reconnectTask = nil }

            while !Task.isCancelled && self.reconnectAttempt < self.maxReconnectAttempts {
                self.reconnectAttempt += 1
                let delaySeconds = UInt64(self.reconnectAttempt * 2)

                #if DEBUG
                print("[AppViewModel] Attempting reconnect #\(self.reconnectAttempt) in \(delaySeconds)s")
                #endif

                do {
                    try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                } catch {
                    return
                }

                if Task.isCancelled {
                    return
                }

                await self.connect(to: device)

                if case .connected = self.connectionState {
                    self.reconnectAttempt = 0
                    return
                }
            }
        }
    }

    private func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0
    }
}

// MARK: - Shared Instance

extension AppViewModel {
    static let shared = AppViewModel()
}
