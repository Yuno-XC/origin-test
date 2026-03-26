//
//  AppViewModelTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

@MainActor
final class AppViewModelTests: XCTestCase {
    // MARK: - NavigationState

    func testNavigationState_equatable() {
        let d1 = TVDevice(name: "A", host: "10.0.0.1")
        let d2 = TVDevice(name: "B", host: "10.0.0.2")
        XCTAssertEqual(AppViewModel.NavigationState.discovery, .discovery)
        XCTAssertEqual(AppViewModel.NavigationState.pairing(d1), .pairing(d1))
        XCTAssertNotEqual(AppViewModel.NavigationState.pairing(d1), .pairing(d2))
        XCTAssertEqual(AppViewModel.NavigationState.remote(d1), .remote(d1))
        XCTAssertNotEqual(AppViewModel.NavigationState.remote(d1), .remote(d2))
        XCTAssertNotEqual(AppViewModel.NavigationState.discovery, .remote(d1))
    }

    func testInit_lastConnectedPaired_autoConnects() async throws {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        let device = TVDevice(name: "Remembered", host: "10.0.0.200", isPaired: true)
        persistence.setLastConnectedDevice(device)
        _ = AppViewModel(adapter: adapter, persistence: persistence)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(adapter.connectCalls.count, 1)
        XCTAssertEqual(adapter.connectCalls.first?.host, "10.0.0.200")
    }

    func testInit_lastConnectedNotPaired_doesNotAutoConnect() async throws {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        var device = TVDevice(name: "Guest", host: "10.0.0.201", isPaired: false)
        persistence.saveDevice(device)
        persistence.setLastConnectedDevice(device)
        _ = AppViewModel(adapter: adapter, persistence: persistence)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(adapter.connectCalls.isEmpty)
    }

    func testAdapterEmitsConnected_keepsConnectedDeviceInSync() async throws {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.202", isPaired: true)
        await vm.connect(to: device)
        adapter.pushConnectionState(.connected)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(vm.connectedDevice?.host, device.host)
    }

    func testSend_whenAdapterThrows_doesNotCrash() async {
        struct SendErr: Error {}
        let adapter = MockTVRemoteAdapter()
        adapter.sendBehavior = .failure(SendErr())
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())
        await vm.send(.volumeUp)
        XCTAssertEqual(adapter.sentActions.last, .volumeUp)
    }

    func testConnect_pairedSuccess_navigatesToRemoteAndPersists() async {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.50", isPaired: true)
        await vm.connect(to: device)
        guard case .remote(let d) = vm.navigationState else {
            XCTFail("expected .remote, got \(vm.navigationState)")
            return
        }
        XCTAssertEqual(d.host, "10.0.0.50")
        XCTAssertEqual(adapter.connectCalls.count, 1)
        XCTAssertEqual(persistence.getLastConnectedDevice()?.host, "10.0.0.50")
    }

    func testConnect_pairedSuccess_setsConnectedDevice() async {
        let adapter = MockTVRemoteAdapter()
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())
        let device = TVDevice(name: "TV", host: "10.0.0.80", isPaired: true)

        await vm.connect(to: device)

        XCTAssertEqual(vm.connectedDevice?.host, device.host)
    }

    func testConnect_unpaired_showsPairing() async {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.51", isPaired: false)
        await vm.connect(to: device)
        guard case .pairing(let d) = vm.navigationState else {
            XCTFail("expected .pairing, got \(vm.navigationState)")
            return
        }
        XCTAssertEqual(d.host, "10.0.0.51")
        XCTAssertTrue(adapter.connectCalls.isEmpty)
    }

    func testConnect_failure_setsDeviceUnreachable() async {
        struct Err: Error {}
        let adapter = MockTVRemoteAdapter()
        adapter.connectBehavior = .failure(Err())
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.52", isPaired: true)
        await vm.connect(to: device)
        guard case .error(let e) = vm.connectionState else {
            XCTFail("expected .error, got \(vm.connectionState)")
            return
        }
        XCTAssertEqual(e, .deviceUnreachable)
    }

    func testConnect_failure_doesNotPersistLastConnectedOrNavigateToRemote() async {
        struct Err: Error {}
        let adapter = MockTVRemoteAdapter()
        adapter.connectBehavior = .failure(Err())
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.77", isPaired: true)

        await vm.connect(to: device)

        XCTAssertNil(persistence.getLastConnectedDevice())
        XCTAssertNil(vm.connectedDevice)
        XCTAssertEqual(vm.navigationState, .discovery)
    }

    func testDisconnect_clearsNavigationToDiscovery() async {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.53", isPaired: true)
        await vm.connect(to: device)
        vm.disconnect()
        XCTAssertEqual(vm.navigationState, .discovery)
        XCTAssertGreaterThanOrEqual(adapter.disconnectCount, 1)
    }

    func testDisconnect_clearsConnectedDevice() async {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.78", isPaired: true)

        await vm.connect(to: device)
        XCTAssertEqual(vm.connectedDevice?.host, device.host)

        vm.disconnect()

        XCTAssertNil(vm.connectedDevice)
    }

    func testSend_forwardsToAdapter() async {
        let adapter = MockTVRemoteAdapter()
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())
        await vm.send(.menu)
        XCTAssertEqual(adapter.sentActions.last, .menu)
    }

    func testSend_withDirection_recordsDirection() async {
        let adapter = MockTVRemoteAdapter()
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())
        await vm.send(.rewind, direction: .startLong)
        XCTAssertEqual(adapter.sentWithDirection.last?.0, .rewind)
        XCTAssertEqual(adapter.sentWithDirection.last?.1, .startLong)
    }

    func testCancelPairing_disconnectsAndReturnsToDiscovery() {
        let adapter = MockTVRemoteAdapter()
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())
        let device = TVDevice(name: "TV", host: "10.0.0.54", isPaired: false)
        vm.showPairing(for: device)
        vm.cancelPairing()
        XCTAssertEqual(vm.navigationState, .discovery)
        XCTAssertGreaterThanOrEqual(adapter.disconnectCount, 1)
    }

    func testShowRemote_setsNavigation() {
        let vm = AppViewModel(adapter: MockTVRemoteAdapter(), persistence: MockPersistence())
        let device = TVDevice(name: "TV", host: "10.0.0.55")
        vm.showRemote(for: device)
        XCTAssertEqual(vm.navigationState, .remote(device))
    }

    func testShowDiscovery_setsNavigation() {
        let vm = AppViewModel(adapter: MockTVRemoteAdapter(), persistence: MockPersistence())
        vm.showRemote(for: TVDevice(name: "TV", host: "10.0.0.56"))
        vm.showDiscovery()
        XCTAssertEqual(vm.navigationState, .discovery)
    }

    func testSubmitPairingCode_whenNotPairing_doesNothing() async {
        let adapter = MockTVRemoteAdapter()
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())
        await vm.submitPairingCode("1234")
        XCTAssertTrue(adapter.submitCodeCalls.isEmpty)
    }

    func testSubmitPairingCode_success_pairsConnectsAndNavigatesRemote() async {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.57", isPaired: false)
        vm.showPairing(for: device)
        await vm.submitPairingCode("9999")
        XCTAssertEqual(adapter.submitCodeCalls, ["9999"])
        guard case .remote(let d) = vm.navigationState else {
            XCTFail("expected remote after pairing")
            return
        }
        XCTAssertTrue(d.isPaired)
        XCTAssertEqual(persistence.loadDevices().first { $0.host == d.host }?.isPaired, true)
    }

    func testSubmitPairingCode_failure_setsPairingFailedError() async {
        struct PairErr: Error {}
        let adapter = MockTVRemoteAdapter()
        adapter.pairingCodeBehavior = .failure(PairErr())
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())
        vm.showPairing(for: TVDevice(name: "TV", host: "10.0.0.58", isPaired: false))
        await vm.submitPairingCode("0000")
        guard case .error(let e) = vm.connectionState else {
            XCTFail("expected error")
            return
        }
        if case .pairingFailed = e {
            XCTAssertTrue(true)
        } else {
            XCTFail("expected pairingFailed, got \(e)")
        }
    }

    func testSubmitPairingCode_failure_doesNotPersistPairedDevice() async {
        struct PairErr: Error {}
        let adapter = MockTVRemoteAdapter()
        adapter.pairingCodeBehavior = .failure(PairErr())
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.81", isPaired: false)

        vm.showPairing(for: device)
        await vm.submitPairingCode("0000")

        XCTAssertNil(persistence.loadDevices().first { $0.host == device.host })
    }

    func testSubmitPairingCode_connectFailure_stillPersistsPairedDevice() async {
        struct ConnectErr: Error {}
        let adapter = MockTVRemoteAdapter()
        adapter.connectBehavior = .failure(ConnectErr())
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.79", isPaired: false)

        vm.showPairing(for: device)
        await vm.submitPairingCode("1234")

        XCTAssertEqual(adapter.submitCodeCalls, ["1234"])
        XCTAssertTrue(persistence.loadDevices().first { $0.host == device.host }?.isPaired == true)
        XCTAssertEqual(vm.connectionState, .error(.deviceUnreachable))
    }

    func testStartPairing_failure_setsPairingFailedError() async {
        struct StartErr: Error {}
        let adapter = MockTVRemoteAdapter()
        adapter.pairingStartBehavior = .failure(StartErr())
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())
        await vm.startPairing(for: TVDevice(name: "TV", host: "10.0.0.59", isPaired: false))
        guard case .error(let e) = vm.connectionState else {
            XCTFail("expected error")
            return
        }
        if case .pairingFailed = e {
            XCTAssertTrue(true)
        } else {
            XCTFail("expected pairingFailed, got \(e)")
        }
    }

    func testStartPairing_success_forwardsToAdapterAndPublishesWaitingForCode() async {
        let adapter = MockTVRemoteAdapter()
        let device = TVDevice(name: "TV", host: "10.0.0.59", isPaired: false)
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())

        await vm.startPairing(for: device)

        XCTAssertEqual(adapter.startPairingCalls, [device])
        XCTAssertEqual(vm.connectionState, .pairing(.waitingForCode))
    }

    func testConnectionLost_schedulesReconnectForConnectedDevice() async throws {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "Living Room", host: "10.0.0.61", isPaired: true)

        await vm.connect(to: device)
        XCTAssertEqual(adapter.connectCalls.count, 1)

        adapter.pushConnectionState(.error(.connectionLost))
        try await Task.sleep(for: .milliseconds(2300))

        XCTAssertEqual(adapter.connectCalls.count, 2)
        XCTAssertEqual(adapter.connectCalls.last?.host, device.host)
    }

    func testConnectionLost_withoutConnectedDevice_doesNotReconnect() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())

        adapter.pushConnectionState(.error(.connectionLost))
        try await Task.sleep(for: .milliseconds(2300))

        XCTAssertTrue(adapter.connectCalls.isEmpty)
    }

    func testConnectionLost_multipleEvents_scheduleSingleReconnectAttempt() async throws {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "Living Room", host: "10.0.0.63", isPaired: true)

        await vm.connect(to: device)
        XCTAssertEqual(adapter.connectCalls.count, 1)

        adapter.pushConnectionState(.error(.connectionLost))
        adapter.pushConnectionState(.error(.connectionLost))
        adapter.pushConnectionState(.error(.connectionLost))

        try await Task.sleep(for: .milliseconds(2300))

        XCTAssertEqual(adapter.connectCalls.count, 2)
        XCTAssertEqual(adapter.connectCalls.last?.host, device.host)
    }

    func testSkipPairingAndConnect_invokesConnect() async throws {
        let adapter = MockTVRemoteAdapter()
        let persistence = MockPersistence()
        let vm = AppViewModel(adapter: adapter, persistence: persistence)
        let device = TVDevice(name: "TV", host: "10.0.0.60", isPaired: false)
        vm.skipPairingAndConnect(device: device)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(adapter.connectCalls.count, 1)
        XCTAssertEqual(adapter.connectCalls.first?.host, "10.0.0.60")
        XCTAssertTrue(persistence.loadDevices().first { $0.host == "10.0.0.60" }?.isPaired == true)
    }

    func testSkipPairingAndConnect_disconnectsExistingSessionBeforeReconnect() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = AppViewModel(adapter: adapter, persistence: MockPersistence())

        vm.skipPairingAndConnect(device: TVDevice(name: "TV", host: "10.0.0.62", isPaired: false))
        try await Task.sleep(for: .milliseconds(400))

        XCTAssertEqual(adapter.disconnectCount, 1)
        XCTAssertEqual(adapter.connectCalls.last?.host, "10.0.0.62")
    }
}
