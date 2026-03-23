//
//  DiscoveryViewModel.swift
//  TVremote
//
//  Device discovery view model
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class DiscoveryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var devices: [TVDevice] = []
    @Published private(set) var savedDevices: [TVDevice] = []
    @Published private(set) var isScanning = false
    @Published var showManualEntry = false
    @Published var manualIP = ""
    @Published var manualIPError: String?

    // MARK: - Services

    private let discoveryService = DeviceDiscoveryService()
    private let persistence = PersistenceService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks

    var onDeviceSelected: ((TVDevice) -> Void)?

    // MARK: - Initialization

    init() {
        setupBindings()
        loadSavedDevices()
    }

    private func setupBindings() {
        discoveryService.discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
            }
            .store(in: &cancellables)

        discoveryService.isScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scanning in
                self?.isScanning = scanning
            }
            .store(in: &cancellables)
    }

    private func loadSavedDevices() {
        savedDevices = persistence.loadDevices()
    }

    // MARK: - Actions

    func startScanning() {
        discoveryService.startScanning()
    }

    func stopScanning() {
        discoveryService.stopScanning()
    }

    func selectDevice(_ device: TVDevice) {
        onDeviceSelected?(device)
    }

    func connectManually(skipPairing: Bool = false) {
        manualIPError = nil

        let ip = manualIP.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !ip.isEmpty else {
            manualIPError = "Please enter an IP address"
            return
        }

        Task {
            do {
                var device = try await discoveryService.manualConnect(host: ip)
                // If skipping pairing, mark as already paired so we go directly to remote
                if skipPairing {
                    device = TVDevice(
                        id: device.id,
                        name: device.name,
                        host: device.host,
                        port: device.port,
                        isPaired: true,
                        lastConnected: nil
                    )
                }
                persistence.saveDevice(device)
                loadSavedDevices()
                showManualEntry = false
                manualIP = ""
                onDeviceSelected?(device)
            } catch {
                manualIPError = "Invalid IP address"
            }
        }
    }

    func removeDevice(_ device: TVDevice) {
        persistence.removeDevice(device)
        loadSavedDevices()
    }

    func refreshSavedDevices() {
        loadSavedDevices()
    }

    // MARK: - Computed Properties

    var allDevices: [TVDevice] {
        // Combine discovered and saved, removing duplicates
        var result = savedDevices

        for device in devices {
            if !result.contains(where: { $0.host == device.host }) {
                result.append(device)
            }
        }

        return result
    }

    var hasDevices: Bool {
        !allDevices.isEmpty
    }

    /// Devices discovered but not yet saved - avoids O(n*m) filter in view body
    var newlyDiscoveredDevices: [TVDevice] {
        let savedHosts = Set(savedDevices.map { $0.host })
        return devices.filter { !savedHosts.contains($0.host) }
    }
}
