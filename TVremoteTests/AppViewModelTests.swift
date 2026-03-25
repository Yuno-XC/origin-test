//
//  AppViewModelTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

@MainActor
final class AppViewModelTests: XCTestCase {
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
}
