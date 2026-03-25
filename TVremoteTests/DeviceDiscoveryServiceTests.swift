//
//  DeviceDiscoveryServiceTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

final class DeviceDiscoveryServiceTests: XCTestCase {
    func testManualConnect_ipv4_returnsDeviceWithNameAndPort() async throws {
        let service = DeviceDiscoveryService()
        let device = try await service.manualConnect(host: "192.168.1.100", port: 6466)
        XCTAssertEqual(device.host, "192.168.1.100")
        XCTAssertEqual(device.port, 6466)
        XCTAssertTrue(device.name.contains("192.168.1.100"))
    }

    func testManualConnect_customPort() async throws {
        let service = DeviceDiscoveryService()
        let device = try await service.manualConnect(host: "10.0.0.1", port: 1234)
        XCTAssertEqual(device.port, 1234)
    }

    func testManualConnect_ipv6_loopback() async throws {
        let service = DeviceDiscoveryService()
        let device = try await service.manualConnect(host: "::1", port: 6466)
        XCTAssertEqual(device.host, "::1")
    }

    func testManualConnect_invalidHost_throwsInvalidAddress() async {
        let service = DeviceDiscoveryService()
        do {
            _ = try await service.manualConnect(host: "not-an-ip", port: 6466)
            XCTFail("expected error")
        } catch let error as DiscoveryError {
            XCTAssertEqual(error, DiscoveryError.invalidAddress)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}

extension DiscoveryError: Equatable {
    static func == (lhs: DiscoveryError, rhs: DiscoveryError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAddress, .invalidAddress),
             (.networkUnavailable, .networkUnavailable),
             (.timeout, .timeout):
            return true
        default:
            return false
        }
    }
}
