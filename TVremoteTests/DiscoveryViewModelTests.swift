//
//  DiscoveryViewModelTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

@MainActor
final class DiscoveryViewModelTests: XCTestCase {
    func testStartScanning_stopScanning_forwardsToService() {
        let discovery = MockDiscoveryService()
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: MockPersistence())
        XCTAssertFalse(discovery.scanningSubject.value)
        vm.startScanning()
        XCTAssertTrue(discovery.scanningSubject.value)
        vm.stopScanning()
        XCTAssertFalse(discovery.scanningSubject.value)
    }

    func testIsScanning_reflectsDiscoveryPublisher() async throws {
        let discovery = MockDiscoveryService()
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: MockPersistence())
        discovery.scanningSubject.send(true)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(vm.isScanning)
    }

    func testHasDevices_trueWhenOnlySavedDevices() {
        let persistence = MockPersistence()
        persistence.saveDevice(TVDevice(name: "Saved Only", host: "10.0.0.99"))
        let vm = DiscoveryViewModel(discoveryService: MockDiscoveryService(), persistence: persistence)
        XCTAssertTrue(vm.hasDevices)
        XCTAssertEqual(vm.allDevices.count, 1)
    }

    func testAllDevices_savedDevicesListedBeforeNewDiscoveries() {
        let discovery = MockDiscoveryService()
        let persistence = MockPersistence()
        persistence.saveDevice(TVDevice(name: "First", host: "10.0.0.1"))
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: persistence)
        discovery.devicesSubject.send([TVDevice(name: "Second", host: "10.0.0.2")])
        XCTAssertEqual(vm.allDevices.map(\.host), ["10.0.0.1", "10.0.0.2"])
    }

    func testConnectManually_whitespaceOnlyShowsError() {
        let vm = DiscoveryViewModel(discoveryService: MockDiscoveryService(), persistence: MockPersistence())
        vm.manualIP = "\t  \n"
        vm.connectManually()
        XCTAssertEqual(vm.manualIPError, "Please enter an IP address")
    }

    func testAllDevices_mergesDiscoveredWithSavedWithoutDuplicateHosts() {
        let discovery = MockDiscoveryService()
        let persistence = MockPersistence()
        persistence.saveDevice(TVDevice(name: "Saved", host: "10.0.0.1"))
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: persistence)
        discovery.devicesSubject.send([
            TVDevice(name: "Found Same Host", host: "10.0.0.1"),
            TVDevice(name: "New", host: "10.0.0.2")
        ])
        let hosts = vm.allDevices.map(\.host).sorted()
        XCTAssertEqual(hosts, ["10.0.0.1", "10.0.0.2"])
    }

    func testNewlyDiscoveredDevices_excludesSavedHosts() {
        let discovery = MockDiscoveryService()
        let persistence = MockPersistence()
        persistence.saveDevice(TVDevice(name: "Saved", host: "10.0.0.1"))
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: persistence)
        discovery.devicesSubject.send([
            TVDevice(name: "A", host: "10.0.0.1"),
            TVDevice(name: "B", host: "10.0.0.3")
        ])
        XCTAssertEqual(vm.newlyDiscoveredDevices.map(\.host), ["10.0.0.3"])
    }

    func testHasDevices_falseWhenEmpty() {
        let vm = DiscoveryViewModel(discoveryService: MockDiscoveryService(), persistence: MockPersistence())
        XCTAssertFalse(vm.hasDevices)
    }

    func testConnectManually_emptyShowsError() {
        let vm = DiscoveryViewModel(discoveryService: MockDiscoveryService(), persistence: MockPersistence())
        vm.manualIP = "   "
        vm.connectManually()
        XCTAssertEqual(vm.manualIPError, "Please enter an IP address")
    }

    func testConnectManually_success_closesSheetAndPersists() async throws {
        let discovery = MockDiscoveryService()
        let persistence = MockPersistence()
        let returned = TVDevice(name: "Android TV (192.168.0.5)", host: "192.168.0.5")
        discovery.manualConnectResult = .success(returned)
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: persistence)
        vm.showManualEntry = true
        vm.manualIP = "192.168.0.5"
        vm.connectManually()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(vm.manualIPError)
        XCTAssertFalse(vm.showManualEntry)
        XCTAssertTrue(persistence.loadDevices().contains { $0.host == "192.168.0.5" })
    }

    func testConnectManually_skipPairing_marksPaired() async throws {
        let discovery = MockDiscoveryService()
        let persistence = MockPersistence()
        discovery.manualConnectResult = .success(TVDevice(name: "TV", host: "10.0.0.9"))
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: persistence)
        vm.manualIP = "10.0.0.9"
        vm.connectManually(skipPairing: true)
        try await Task.sleep(for: .milliseconds(300))
        let saved = persistence.loadDevices().first { $0.host == "10.0.0.9" }
        XCTAssertTrue(saved?.isPaired == true)
    }

    func testConnectManually_trimsWhitespaceBeforeCallingService() async throws {
        let discovery = MockDiscoveryService()
        discovery.manualConnectResult = .success(TVDevice(name: "TV", host: "10.0.0.72"))
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: MockPersistence())

        vm.manualIP = "  10.0.0.72 \n"
        vm.connectManually()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(discovery.manualConnectCalls.count, 1)
        XCTAssertEqual(discovery.manualConnectCalls.first?.host, "10.0.0.72")
        XCTAssertEqual(discovery.manualConnectCalls.first?.port, 6466)
    }

    func testConnectManually_success_invokesOnDeviceSelectedCallback() async throws {
        let discovery = MockDiscoveryService()
        let returned = TVDevice(name: "TV", host: "10.0.0.73")
        discovery.manualConnectResult = .success(returned)
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: MockPersistence())
        let expect = expectation(description: "selected after manual connect")

        vm.onDeviceSelected = { device in
            XCTAssertEqual(device.host, returned.host)
            expect.fulfill()
        }

        vm.manualIP = returned.host
        vm.connectManually()

        await fulfillment(of: [expect], timeout: 1.0)
    }

    func testRemoveDevice_updatesSavedList() {
        let persistence = MockPersistence()
        let d = TVDevice(name: "X", host: "10.0.0.4")
        persistence.saveDevice(d)
        let vm = DiscoveryViewModel(discoveryService: MockDiscoveryService(), persistence: persistence)
        vm.removeDevice(d)
        XCTAssertTrue(persistence.loadDevices().isEmpty)
    }

    func testRefreshSavedDevices_reflectsPersistenceChanges() {
        let persistence = MockPersistence()
        let vm = DiscoveryViewModel(discoveryService: MockDiscoveryService(), persistence: persistence)
        persistence.saveDevice(TVDevice(name: "Late", host: "10.0.0.8"))
        vm.refreshSavedDevices()
        XCTAssertEqual(vm.savedDevices.count, 1)
    }

    func testConnectManually_failure_setsInvalidIPError() async throws {
        let discovery = MockDiscoveryService()
        discovery.manualConnectResult = .failure(DiscoveryError.invalidAddress)
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: MockPersistence())
        vm.showManualEntry = true
        vm.manualIP = "192.168.0.1"
        vm.connectManually()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(vm.manualIPError, "Invalid IP address")
        XCTAssertTrue(vm.showManualEntry)
    }

    func testSelectDevice_invokesOnDeviceSelected() {
        let vm = DiscoveryViewModel(discoveryService: MockDiscoveryService(), persistence: MockPersistence())
        let picked = TVDevice(name: "Pick", host: "10.0.0.70")
        let expect = expectation(description: "selected")
        vm.onDeviceSelected = { device in
            XCTAssertEqual(device.host, picked.host)
            expect.fulfill()
        }
        vm.selectDevice(picked)
        wait(for: [expect], timeout: 1)
    }

    func testAllDevices_prefersSavedNameWhenSameHost() {
        let discovery = MockDiscoveryService()
        let persistence = MockPersistence()
        persistence.saveDevice(TVDevice(name: "Saved Name", host: "10.0.0.71"))
        let vm = DiscoveryViewModel(discoveryService: discovery, persistence: persistence)
        discovery.devicesSubject.send([
            TVDevice(name: "Bonjour Name", host: "10.0.0.71")
        ])
        let match = vm.allDevices.first { $0.host == "10.0.0.71" }
        XCTAssertEqual(match?.name, "Saved Name")
    }
}
