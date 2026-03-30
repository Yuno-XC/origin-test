//
//  PersistenceServiceTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

final class PersistenceServiceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var sut: PersistenceService!

    override func setUp() {
        super.setUp()
        suiteName = "test.PersistenceService.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        sut = PersistenceService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testSaveDevice_appendsNewHost() {
        let a = TVDevice(name: "A", host: "10.0.0.1")
        sut.saveDevice(a)
        XCTAssertEqual(sut.loadDevices().count, 1)
        XCTAssertEqual(sut.loadDevices().first?.host, "10.0.0.1")
    }

    func testSaveDevice_sameHost_replacesEntry() {
        let first = TVDevice(name: "Old", host: "10.0.0.2")
        sut.saveDevice(first)
        let second = TVDevice(name: "New", host: "10.0.0.2", isPaired: true)
        sut.saveDevice(second)
        let loaded = sut.loadDevices()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "New")
        XCTAssertTrue(loaded.first?.isPaired == true)
    }

    func testSetLastConnectedDevice_persistsIdAndTouchesLastConnected() throws {
        let device = TVDevice(name: "TV", host: "192.168.0.10")
        sut.saveDevice(device)
        let before = Date()
        sut.setLastConnectedDevice(device)
        let resolved = try XCTUnwrap(sut.getLastConnectedDevice())
        XCTAssertEqual(resolved.id, device.id)
        XCTAssertGreaterThanOrEqual(resolved.lastConnected ?? before, before)
    }

    func testGetLastConnectedDevice_nilWhenNoMatch() {
        sut.saveDevice(TVDevice(name: "TV", host: "10.0.0.3"))
        defaults.set(UUID().uuidString, forKey: "lastConnectedDeviceId")
        XCTAssertNil(sut.getLastConnectedDevice())
    }

    func testRemoveDevice_dropsFromList() {
        let d = TVDevice(name: "X", host: "10.0.0.4")
        sut.saveDevice(d)
        sut.removeDevice(d)
        XCTAssertTrue(sut.loadDevices().isEmpty)
    }

    func testSavePreference_loadPreference_roundTrip() {
        struct Box: Codable, Equatable {
            let n: Int
        }
        sut.savePreference(Box(n: 42), forKey: "box")
        let loaded: Box? = sut.loadPreference(forKey: "box")
        XCTAssertEqual(loaded, Box(n: 42))
    }

    func testLoadPreference_missingReturnsNil() {
        let value: String? = sut.loadPreference(forKey: "nope")
        XCTAssertNil(value)
    }

    func testLoadPreference_invalidJSON_returnsNil() {
        defaults.set(Data("{not json".utf8), forKey: "bad")
        let value: String? = sut.loadPreference(forKey: "bad")
        XCTAssertNil(value)
    }

    func testLoadDevices_corruptJSON_returnsEmpty() {
        defaults.set(Data("{".utf8), forKey: "savedDevices")
        XCTAssertTrue(sut.loadDevices().isEmpty)
    }

    func testRemoveDevice_clearsLastConnectedWhenRemovedDeviceWasLast() throws {
        let device = TVDevice(name: "TV", host: "10.0.0.20")
        sut.saveDevice(device)
        sut.setLastConnectedDevice(device)
        _ = try XCTUnwrap(sut.getLastConnectedDevice())
        sut.removeDevice(device)
        XCTAssertNil(sut.getLastConnectedDevice())
        XCTAssertTrue(sut.loadDevices().isEmpty)
    }

    func testSaveDevice_multipleDistinctHosts_appendsInOrder() {
        let a = TVDevice(name: "A", host: "10.0.0.30")
        let b = TVDevice(name: "B", host: "10.0.0.31")
        sut.saveDevice(a)
        sut.saveDevice(b)
        XCTAssertEqual(sut.loadDevices().map(\.host), ["10.0.0.30", "10.0.0.31"])
    }

    func testRemoveDevice_preservesLastConnectedWhenRemovingOtherHost() throws {
        let primary = TVDevice(name: "Main", host: "10.0.0.40")
        let other = TVDevice(name: "Guest", host: "10.0.0.41")
        sut.saveDevice(primary)
        sut.saveDevice(other)
        sut.setLastConnectedDevice(primary)
        let before = try XCTUnwrap(sut.getLastConnectedDevice())
        XCTAssertEqual(before.host, primary.host)

        sut.removeDevice(other)

        let after = try XCTUnwrap(sut.getLastConnectedDevice())
        XCTAssertEqual(after.host, primary.host)
        XCTAssertEqual(sut.loadDevices().count, 1)
        XCTAssertEqual(sut.loadDevices().first?.host, primary.host)
    }

    func testSaveCertificate_loadCertificate_roundTrip() {
        let device = TVDevice(name: "TV", host: "10.0.0.50")
        let certificate = Data("certificate-data".utf8)

        sut.saveCertificate(certificate, for: device)

        XCTAssertEqual(sut.loadCertificate(for: device), certificate)
    }

    func testRemoveDevice_removesStoredCertificate() {
        let device = TVDevice(name: "TV", host: "10.0.0.51")
        sut.saveDevice(device)
        sut.saveCertificate(Data("certificate".utf8), for: device)

        sut.removeDevice(device)

        XCTAssertNil(sut.loadCertificate(for: device))
    }

    func testSaveDevice_sameHostDifferentPort_keepsDistinctEntries() {
        let first = TVDevice(name: "TV 80", host: "10.0.0.52", port: 80)
        let second = TVDevice(name: "TV 6466", host: "10.0.0.52", port: 6466)

        sut.saveDevice(first)
        sut.saveDevice(second)

        let loaded = sut.loadDevices().sorted { $0.port < $1.port }
        XCTAssertEqual(loaded.map(\.port), [80, 6466])
    }

    func testRememberRecentText_persistsMostRecentFirst() {
        sut.rememberRecentText("Netflix")
        sut.rememberRecentText("YouTube")

        XCTAssertEqual(sut.loadRecentTexts(), ["YouTube", "Netflix"])
    }

    func testRememberRecentText_deduplicatesExistingEntry() {
        sut.rememberRecentText("Disney+")
        sut.rememberRecentText("YouTube")
        sut.rememberRecentText("Disney+")

        XCTAssertEqual(sut.loadRecentTexts(), ["Disney+", "YouTube"])
    }

    func testRememberRecentText_ignoresWhitespaceOnlyValues() {
        sut.rememberRecentText("   ")

        XCTAssertTrue(sut.loadRecentTexts().isEmpty)
    }

    func testRememberRecentText_enforcesLimit() {
        for index in 0..<10 {
            sut.rememberRecentText("Text \(index)", limit: 4)
        }

        XCTAssertEqual(sut.loadRecentTexts(), ["Text 9", "Text 8", "Text 7", "Text 6"])
    }

    func testClearRecentTexts_removesSavedHistory() {
        sut.rememberRecentText("Search")

        sut.clearRecentTexts()

        XCTAssertTrue(sut.loadRecentTexts().isEmpty)
    }
}
