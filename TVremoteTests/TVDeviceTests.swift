//
//  TVDeviceTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

final class TVDeviceTests: XCTestCase {
    func testEquatable_usesHostAndPort_notId() {
        let a = TVDevice(id: UUID(), name: "A", host: "10.0.0.1", port: 6466)
        let b = TVDevice(id: UUID(), name: "B", host: "10.0.0.1", port: 6466)
        XCTAssertEqual(a, b)
    }

    func testHashable_stableForSameHostPort() {
        let a = TVDevice(name: "One", host: "10.0.0.2", port: 6466)
        let b = TVDevice(name: "Two", host: "10.0.0.2", port: 6466)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testCodable_roundTrip() throws {
        let original = TVDevice(
            name: "Living Room",
            host: "192.168.1.10",
            port: 6466,
            isPaired: true,
            lastConnected: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TVDevice.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.host, original.host)
        XCTAssertEqual(decoded.port, original.port)
        XCTAssertEqual(decoded.isPaired, original.isPaired)
        XCTAssertEqual(decoded, original)
    }

    /// `TVDevice.==` compares only host and port; persistence still must round-trip id, name, and dates.
    func testCodable_roundTrip_preservesIdNameAndLastConnected() throws {
        let id = UUID()
        let lastConnected = Date(timeIntervalSince1970: 1_750_000_000)
        let original = TVDevice(
            id: id,
            name: "Office TV",
            host: "10.0.0.50",
            port: 6466,
            isPaired: true,
            lastConnected: lastConnected
        )
        let decoded = try JSONDecoder().decode(
            TVDevice.self,
            from: try JSONEncoder().encode(original)
        )
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.name, "Office TV")
        XCTAssertEqual(decoded.lastConnected, lastConnected)
        XCTAssertTrue(decoded.isPaired)
    }

    func testDefaultPort() {
        let d = TVDevice(name: "TV", host: "1.1.1.1")
        XCTAssertEqual(d.port, 6466)
    }

    func testEquatable_differentPort_notEqual() {
        let a = TVDevice(name: "TV", host: "10.0.0.1", port: 6466)
        let b = TVDevice(name: "TV", host: "10.0.0.1", port: 6467)
        XCTAssertNotEqual(a, b)
    }
}
