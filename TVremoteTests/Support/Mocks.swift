//
//  Mocks.swift
//  TVremoteTests
//

import Combine
import Foundation
@testable import TVremote

// MARK: - Mock remote adapter

final class MockTVRemoteAdapter: TVRemoteAdapterProtocol {
    private let stateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)

    var connectionState: AnyPublisher<ConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var currentState: ConnectionState { stateSubject.value }

    private(set) var currentDevice: TVDevice?

    var connectBehavior: Result<Void, Error> = .success(())
    var pairingStartBehavior: Result<Void, Error> = .success(())
    var pairingCodeBehavior: Result<Void, Error> = .success(())
    var sendBehavior: Result<Void, Error> = .success(())

    private(set) var connectCalls: [TVDevice] = []
    private(set) var disconnectCount = 0
    private(set) var startPairingCalls: [TVDevice] = []
    private(set) var submitCodeCalls: [String] = []
    private(set) var sentActions: [RemoteAction] = []
    private(set) var sentWithDirection: [(RemoteAction, KeyPressDirection)] = []

    func connect(to device: TVDevice) async throws {
        connectCalls.append(device)
        switch connectBehavior {
        case .success:
            currentDevice = device
            stateSubject.send(.connected)
        case .failure(let error):
            throw error
        }
    }

    func disconnect() {
        disconnectCount += 1
        currentDevice = nil
        stateSubject.send(.disconnected)
    }

    func startPairing(to device: TVDevice) async throws {
        startPairingCalls.append(device)
        switch pairingStartBehavior {
        case .success:
            currentDevice = device
            stateSubject.send(.pairing(.waitingForCode))
        case .failure(let error):
            throw error
        }
    }

    func submitPairingCode(_ code: String) async throws {
        submitCodeCalls.append(code)
        switch pairingCodeBehavior {
        case .success:
            stateSubject.send(.pairing(.success))
        case .failure(let error):
            throw error
        }
    }

    func send(_ action: RemoteAction) async throws {
        try await send(action, direction: .short)
    }

    func send(_ action: RemoteAction, direction: KeyPressDirection) async throws {
        sentActions.append(action)
        sentWithDirection.append((action, direction))
        switch sendBehavior {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    func pushConnectionState(_ state: ConnectionState) {
        stateSubject.send(state)
    }
}

// MARK: - Mock persistence

final class MockPersistence: PersistenceProtocol {
    private(set) var devices: [TVDevice] = []
    private var lastConnectedId: UUID?
    private var certificates: [UUID: Data] = [:]

    func saveDevice(_ device: TVDevice) {
        if let index = devices.firstIndex(where: { $0.host == device.host && $0.port == device.port }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
    }

    func loadDevices() -> [TVDevice] {
        devices
    }

    func removeDevice(_ device: TVDevice) {
        devices.removeAll { $0.id == device.id }
        certificates.removeValue(forKey: device.id)
        if lastConnectedId == device.id {
            lastConnectedId = nil
        }
    }

    func setLastConnectedDevice(_ device: TVDevice) {
        lastConnectedId = device.id
        var updated = device
        updated.lastConnected = Date()
        saveDevice(updated)
    }

    func getLastConnectedDevice() -> TVDevice? {
        guard let id = lastConnectedId else { return nil }
        return devices.first { $0.id == id }
    }

    func saveCertificate(_ data: Data, for device: TVDevice) {
        certificates[device.id] = data
    }

    func loadCertificate(for device: TVDevice) -> Data? {
        certificates[device.id]
    }
}

// MARK: - Mock discovery

final class MockDiscoveryService: DeviceDiscoveryProtocol {
    let devicesSubject = CurrentValueSubject<[TVDevice], Never>([])
    let scanningSubject = CurrentValueSubject<Bool, Never>(false)

    var discoveredDevices: AnyPublisher<[TVDevice], Never> {
        devicesSubject.eraseToAnyPublisher()
    }

    var isScanning: AnyPublisher<Bool, Never> {
        scanningSubject.eraseToAnyPublisher()
    }

    var manualConnectResult: Result<TVDevice, Error> = .failure(DiscoveryError.invalidAddress)
    private(set) var manualConnectCalls: [(host: String, port: Int)] = []

    func startScanning() {
        scanningSubject.send(true)
    }

    func stopScanning() {
        scanningSubject.send(false)
    }

    func manualConnect(host: String, port: Int) async throws -> TVDevice {
        manualConnectCalls.append((host, port))
        switch manualConnectResult {
        case .success(let device):
            return device
        case .failure(let error):
            throw error
        }
    }
}
