//
//  ConnectionModelsTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

final class ConnectionModelsTests: XCTestCase {
    // MARK: - ConnectionState

    func testConnectionState_isConnected() {
        XCTAssertFalse(ConnectionState.disconnected.isConnected)
        XCTAssertFalse(ConnectionState.connecting.isConnected)
        XCTAssertFalse(ConnectionState.pairing(.waitingForCode).isConnected)
        XCTAssertFalse(ConnectionState.pairing(.success).isConnected)
        XCTAssertTrue(ConnectionState.connected.isConnected)
        XCTAssertFalse(ConnectionState.error(.timeout).isConnected)
    }

    func testConnectionState_displayText() {
        XCTAssertEqual(ConnectionState.disconnected.displayText, "Not Connected")
        XCTAssertEqual(ConnectionState.connecting.displayText, "Connecting...")
        XCTAssertEqual(ConnectionState.connected.displayText, "Connected")
        XCTAssertEqual(ConnectionState.pairing(.starting).displayText, "Starting pairing...")
        XCTAssertEqual(ConnectionState.pairing(.waitingForCode).displayText, "Enter code shown on TV")
        XCTAssertEqual(ConnectionState.pairing(.validatingCode).displayText, "Validating...")
        XCTAssertEqual(ConnectionState.pairing(.success).displayText, "Paired successfully")
        XCTAssertEqual(ConnectionState.error(.networkUnavailable).displayText, "Network unavailable")
        XCTAssertEqual(ConnectionState.error(.deviceUnreachable).displayText, "TV not reachable")
        XCTAssertEqual(ConnectionState.error(.pairingRequired).displayText, "Pairing required")
        XCTAssertEqual(ConnectionState.error(.timeout).displayText, "Connection timed out")
        XCTAssertEqual(ConnectionState.error(.certificateError).displayText, "Security error")
        XCTAssertEqual(ConnectionState.error(.connectionLost).displayText, "Connection lost")
        XCTAssertEqual(ConnectionState.error(.unknown("x")).displayText, "x")
    }

    // MARK: - PairingState

    func testPairingState_displayText_failedIncludesReason() {
        let text = PairingState.failed("bad").displayText
        XCTAssertTrue(text.contains("bad"))
    }

    // MARK: - ConnectionError

    func testConnectionError_localizedDescription() {
        XCTAssertEqual(ConnectionError.pairingFailed("x").localizedDescription, "Pairing failed: x")
        XCTAssertEqual(ConnectionError.unknown("msg").localizedDescription, "msg")
    }

    func testConnectionError_recoveryHint_coversCases() {
        XCTAssertFalse(ConnectionError.networkUnavailable.recoveryHint.isEmpty)
        XCTAssertFalse(ConnectionError.deviceUnreachable.recoveryHint.isEmpty)
        XCTAssertFalse(ConnectionError.pairingRequired.recoveryHint.isEmpty)
        XCTAssertFalse(ConnectionError.pairingFailed("").recoveryHint.isEmpty)
        XCTAssertFalse(ConnectionError.connectionLost.recoveryHint.isEmpty)
        XCTAssertFalse(ConnectionError.timeout.recoveryHint.isEmpty)
        XCTAssertFalse(ConnectionError.certificateError.recoveryHint.isEmpty)
        XCTAssertFalse(ConnectionError.unknown("").recoveryHint.isEmpty)
    }

    func testConnectionError_equatable() {
        XCTAssertEqual(ConnectionError.pairingFailed("a"), ConnectionError.pairingFailed("a"))
        XCTAssertNotEqual(ConnectionError.pairingFailed("a"), ConnectionError.pairingFailed("b"))
    }

    func testConnectionState_equatable() {
        XCTAssertEqual(ConnectionState.disconnected, ConnectionState.disconnected)
        XCTAssertEqual(ConnectionState.connected, ConnectionState.connected)
        XCTAssertEqual(ConnectionState.pairing(.waitingForCode), ConnectionState.pairing(.waitingForCode))
        XCTAssertNotEqual(ConnectionState.connecting, ConnectionState.connected)
        XCTAssertEqual(ConnectionState.error(.timeout), ConnectionState.error(.timeout))
        XCTAssertNotEqual(ConnectionState.error(.timeout), ConnectionState.error(.connectionLost))
    }

    func testPairingState_equatable() {
        XCTAssertEqual(PairingState.failed("x"), PairingState.failed("x"))
        XCTAssertNotEqual(PairingState.failed("x"), PairingState.failed("y"))
    }
}
