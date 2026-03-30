//
//  AndroidTVAdapterTests.swift
//  TVremoteTests
//

import XCTest
import Combine
@testable import TVremote

@MainActor
final class AndroidTVAdapterTests: XCTestCase {
    private func assertPairingFailed(
        _ operation: @escaping () async throws -> Void,
        messageContains expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected pairingFailed error", file: file, line: line)
        } catch let error as ConnectionError {
            guard case .pairingFailed(let message) = error else {
                XCTFail("Expected pairingFailed, got \(error)", file: file, line: line)
                return
            }
            XCTAssertTrue(message.contains(expectedMessage), "Message was: \(message)", file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    private func assertPairingFailedExactMessage(
        _ operation: @escaping () async throws -> Void,
        expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected pairingFailed error", file: file, line: line)
        } catch let error as ConnectionError {
            guard case .pairingFailed(let message) = error else {
                XCTFail("Expected pairingFailed, got \(error)", file: file, line: line)
                return
            }
            XCTAssertEqual(message, expectedMessage, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    // MARK: - Initial State Tests

    func testInitialState_isDisconnected() {
        let adapter = AndroidTVAdapter()
        XCTAssertEqual(adapter.currentState, .disconnected)
    }

    func testInitialState_hasNoDevice() {
        let adapter = AndroidTVAdapter()
        XCTAssertNil(adapter.currentDevice)
    }

    // MARK: - Send Action Tests

    func testSend_withoutCurrentDevice_throwsDeviceUnreachable() async {
        let adapter = AndroidTVAdapter()

        do {
            try await adapter.send(.home)
            XCTFail("Expected deviceUnreachable error")
        } catch let error as ConnectionError {
            XCTAssertEqual(error, .deviceUnreachable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSend_variousActions_withoutDevice_allThrowDeviceUnreachable() async {
        let adapter = AndroidTVAdapter()
        let actions: [RemoteAction] = [
            .home, .back, .menu, .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
            .playPause, .volumeUp, .volumeDown, .channelDigit(3), .power, .enter
        ]

        for action in actions {
            do {
                try await adapter.send(action)
                XCTFail("Expected deviceUnreachable for action: \(action)")
            } catch let error as ConnectionError {
                XCTAssertEqual(error, .deviceUnreachable, "Expected deviceUnreachable for action: \(action)")
            } catch {
                XCTFail("Unexpected error for action \(action): \(error)")
            }
        }
    }

    // MARK: - Pairing Code Validation Tests

    func testSubmitPairingCode_withInvalidLength_throwsPairingFailed() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailed({ try await adapter.submitPairingCode("12345") }, messageContains: "6 hex characters")
    }

    func testSubmitPairingCode_withTooLongLength_throwsPairingFailed() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailed({ try await adapter.submitPairingCode("123456789") }, messageContains: "6 hex characters")
    }

    func testSubmitPairingCode_withNonHexCharacters_throwsPairingFailed() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailed({ try await adapter.submitPairingCode("12GH!@") }, messageContains: "6 hex characters")
    }

    func testSubmitPairingCode_withInvalidCharacters_lowercase_throwsPairingFailed() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailed({ try await adapter.submitPairingCode("12zxcv") }, messageContains: "6 hex characters")
    }

    func testSubmitPairingCode_withoutActivePairingSession_throwsPairingFailed() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailedExactMessage(
            { try await adapter.submitPairingCode("a1b2c3") },
            expectedMessage: "No active pairing session"
        )
    }

    func testSubmitPairingCode_withValidMixedCaseHex_withoutActivePairingSession_throwsNoActiveSession() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailedExactMessage(
            { try await adapter.submitPairingCode("A1b2C3") },
            expectedMessage: "No active pairing session"
        )
    }

    func testSubmitPairingCode_acceptsValidHexLowercase() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailedExactMessage(
            { try await adapter.submitPairingCode("abcdef") },
            expectedMessage: "No active pairing session"
        )
    }

    func testSubmitPairingCode_acceptsValidHexUppercase() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailedExactMessage(
            { try await adapter.submitPairingCode("ABCDEF") },
            expectedMessage: "No active pairing session"
        )
    }

    func testSubmitPairingCode_acceptsValidHexNumbers() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailedExactMessage(
            { try await adapter.submitPairingCode("123456") },
            expectedMessage: "No active pairing session"
        )
    }

    // MARK: - Disconnect Tests

    func testDisconnect_onFreshAdapter_keepsDisconnectedState() {
        let adapter = AndroidTVAdapter()
        adapter.disconnect()

        XCTAssertNil(adapter.currentDevice)
        XCTAssertEqual(adapter.currentState, .disconnected)
    }

    func testDisconnect_clearsCurrentDevice() {
        let adapter = AndroidTVAdapter()
        adapter.disconnect()

        XCTAssertNil(adapter.currentDevice)
    }

    // MARK: - Connection State Publisher Tests

    func testConnectionStatePublisher_emitsDisconnectedInitially() {
        let adapter = AndroidTVAdapter()
        var receivedStates: [ConnectionState] = []
        let cancellable = adapter.connectionState.sink { state in
            receivedStates.append(state)
        }

        XCTAssertEqual(receivedStates, [.disconnected])
        cancellable.cancel()
    }

    func testConnectionStatePublisher_emitsWhenDisconnectCalled() {
        let adapter = AndroidTVAdapter()
        var receivedStates: [ConnectionState] = []
        let cancellable = adapter.connectionState.sink { state in
            receivedStates.append(state)
        }

        adapter.disconnect()

        XCTAssertEqual(receivedStates, [.disconnected, .disconnected])
        cancellable.cancel()
    }

    // MARK: - Edge Cases

    func testPairingCodeValidation_emptyString() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailed({ try await adapter.submitPairingCode("") }, messageContains: "6 hex characters")
    }

    func testPairingCodeValidation_whitespace() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailed({ try await adapter.submitPairingCode("a1 b2c3") }, messageContains: "6 hex characters")
    }

    func testPairingCodeValidation_specialCharacters() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailed({ try await adapter.submitPairingCode("a1b2c@") }, messageContains: "6 hex characters")
    }

    func testPairingCodeValidation_nonASCIICharacters() async {
        let adapter = AndroidTVAdapter()
        await assertPairingFailed({ try await adapter.submitPairingCode("é1b2c3") }, messageContains: "6 hex characters")
    }
}
