//
//  RemoteControlProtocol.swift
//  TVremote
//
//  Protocol definitions for remote control adapters
//

import Foundation
import Combine

/// Protocol for TV connection management
protocol TVConnectionProtocol: AnyObject {
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    var currentState: ConnectionState { get }
    var currentDevice: TVDevice? { get }

    func connect(to device: TVDevice) async throws
    func disconnect()
    func startPairing(to device: TVDevice) async throws
    func submitPairingCode(_ code: String) async throws
}

/// Protocol for sending remote commands to TV
protocol RemoteCommandProtocol: AnyObject {
    func send(_ action: RemoteAction) async throws
    func send(_ action: RemoteAction, direction: KeyPressDirection) async throws
}

/// Combined protocol for full TV remote functionality
protocol TVRemoteAdapterProtocol: TVConnectionProtocol, RemoteCommandProtocol {}

/// Protocol for device discovery
protocol DeviceDiscoveryProtocol: AnyObject {
    var discoveredDevices: AnyPublisher<[TVDevice], Never> { get }
    var isScanning: AnyPublisher<Bool, Never> { get }

    func startScanning()
    func stopScanning()
    func manualConnect(host: String, port: Int) async throws -> TVDevice
}

extension DeviceDiscoveryProtocol {
    func manualConnect(host: String) async throws -> TVDevice {
        try await manualConnect(host: host, port: 6466)
    }
}

/// Protocol for persistence
protocol PersistenceProtocol {
    func saveDevice(_ device: TVDevice)
    func loadDevices() -> [TVDevice]
    func removeDevice(_ device: TVDevice)
    func setLastConnectedDevice(_ device: TVDevice)
    func getLastConnectedDevice() -> TVDevice?
    func saveCertificate(_ data: Data, for device: TVDevice)
    func loadCertificate(for device: TVDevice) -> Data?
}
