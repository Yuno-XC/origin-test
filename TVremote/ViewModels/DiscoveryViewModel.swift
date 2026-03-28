//
//  DiscoveryViewModel.swift
//  TVremote
//
//  Device discovery view model
//

import Foundation
import Combine
import SwiftUI

enum DiscoveryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case saved = "Saved"
    case newlyDiscovered = "New"

    var id: String { rawValue }
}

@MainActor
final class DiscoveryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var devices: [TVDevice] = []
    @Published private(set) var savedDevices: [TVDevice] = []
    @Published private(set) var allDevices: [TVDevice] = []
    @Published private(set) var newlyDiscoveredDevices: [TVDevice] = []
    @Published private(set) var isScanning = false
    @Published var searchQuery = ""
    @Published var selectedFilter: DiscoveryFilter = .all
    @Published var showManualEntry = false
    @Published var manualIP = ""
    @Published var manualIPError: String?

    // MARK: - Services

    private let discoveryService: DeviceDiscoveryProtocol
    private let persistence: PersistenceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks

    var onDeviceSelected: ((TVDevice) -> Void)?

    // MARK: - Initialization

    init(
        discoveryService: DeviceDiscoveryProtocol = DeviceDiscoveryService(),
        persistence: PersistenceProtocol = PersistenceService.shared
    ) {
        self.discoveryService = discoveryService
        self.persistence = persistence
        setupBindings()
        loadSavedDevices()
    }

    private func setupBindings() {
        discoveryService.discoveredDevices
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
                self?.rebuildDeviceLists()
            }
            .store(in: &cancellables)

        discoveryService.isScanning
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scanning in
                self?.isScanning = scanning
            }
            .store(in: &cancellables)
    }

    private func loadSavedDevices() {
        let loadedDevices = persistence.loadDevices()
        if loadedDevices != savedDevices {
            savedDevices = loadedDevices
            rebuildDeviceLists()
        }
    }

    private func rebuildDeviceLists() {
        let savedHosts = Set(savedDevices.map(\.host))
        let discoveredOnly = devices.filter { !savedHosts.contains($0.host) }
        let mergedDevices = savedDevices + discoveredOnly

        if newlyDiscoveredDevices != discoveredOnly {
            newlyDiscoveredDevices = discoveredOnly
        }

        if allDevices != mergedDevices {
            allDevices = mergedDevices
        }
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

    var hasDevices: Bool {
        !allDevices.isEmpty
    }

    var filteredSavedDevices: [TVDevice] {
        guard selectedFilter != .newlyDiscovered else { return [] }
        return filter(devices: savedDevices)
    }

    var filteredNewlyDiscoveredDevices: [TVDevice] {
        guard selectedFilter != .saved else { return [] }
        return filter(devices: newlyDiscoveredDevices)
    }

    var hasVisibleDevices: Bool {
        !filteredSavedDevices.isEmpty || !filteredNewlyDiscoveredDevices.isEmpty
    }

    private func filter(devices: [TVDevice]) -> [TVDevice] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return devices }

        let loweredQuery = query.lowercased()
        return devices.filter {
            $0.name.lowercased().contains(loweredQuery)
                || $0.host.lowercased().contains(loweredQuery)
        }
    }
}
