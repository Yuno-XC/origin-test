//
//  SmokeTests.swift
//  TVremoteTests
//
//  Lightweight sanity checks for the test target (CI / local verification).
//

import XCTest
@testable import TVremote

final class SmokeTests: XCTestCase {
    func test_bundleLoads() {
        let bundle = Bundle(for: SmokeTests.self)
        XCTAssertNotNil(bundle.bundleIdentifier)
    }

    func test_tvDevice_defaultAndroidTVPort() {
        let device = TVDevice(name: "Test", host: "192.168.0.1")
        XCTAssertEqual(device.port, 6466)
    }

    func test_tvDevice_defaultNotPaired() {
        let device = TVDevice(name: "Test", host: "192.168.0.1")
        XCTAssertFalse(device.isPaired)
    }

    func test_tvDevice_explicitPortPreserved() {
        let device = TVDevice(name: "Test", host: "10.0.0.1", port: 9_000)
        XCTAssertEqual(device.port, 9_000)
    }
}
