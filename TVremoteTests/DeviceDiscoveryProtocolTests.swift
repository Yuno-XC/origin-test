//
//  DeviceDiscoveryProtocolTests.swift
//  TVremoteTests
//

import XCTest
import Combine
@testable import TVremote

private final class StubDiscovery: DeviceDiscoveryProtocol {
    var discoveredDevices: AnyPublisher<[TVDevice], Never> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    var isScanning: AnyPublisher<Bool, Never> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    func startScanning() {}
    func stopScanning() {}

    func manualConnect(host: String, port: Int) async throws -> TVDevice {
        TVDevice(name: "stub-\(host)", host: host, port: port)
    }
}

private final class PassthroughDiscovery: DeviceDiscoveryProtocol {
    var discoveredDevices: AnyPublisher<[TVDevice], Never> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    var isScanning: AnyPublisher<Bool, Never> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    func startScanning() {}
    func stopScanning() {}

    func manualConnect(host: String, port: Int) async throws -> TVDevice {
        TVDevice(name: "p-\(host)", host: host, port: port)
    }
}

final class DeviceDiscoveryProtocolTests: XCTestCase {
    func testDeviceDiscoveryProtocol_extension_manualConnectHostOnly_usesPort6466() async throws {
        let sut = PassthroughDiscovery()
        let device = try await sut.manualConnect(host: "192.168.0.2")
        XCTAssertEqual(device.port, 6466)
        XCTAssertEqual(device.host, "192.168.0.2")
    }

    func testManualConnect_hostOnly_usesDefaultPort6466() async throws {
        let stub = StubDiscovery()
        let device = try await stub.manualConnect(host: "192.168.0.50")
        XCTAssertEqual(device.host, "192.168.0.50")
        XCTAssertEqual(device.port, 6466)
    }

    func testManualConnect_explicitPort_overridesDefault() async throws {
        let stub = StubDiscovery()
        let device = try await stub.manualConnect(host: "10.0.0.1", port: 9999)
        XCTAssertEqual(device.port, 9999)
    }
}
