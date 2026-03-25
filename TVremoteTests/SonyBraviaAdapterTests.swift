//
//  SonyBraviaAdapterTests.swift
//  TVremoteTests
//

import Combine
import XCTest
@testable import TVremote

final class SonyBraviaAdapterTests: XCTestCase {
    override func tearDown() {
        MockURLSession.requestHandler = nil
        super.tearDown()
    }

    private func makeAdapter(host: String = "192.168.1.50") -> (SonyBraviaAdapter, URLSession) {
        let session = MockURLProtocol.makeEphemeralSession()
        let adapter = SonyBraviaAdapter(host: host, urlSession: session)
        return (adapter, session)
    }

    private var sampleDevice: TVDevice {
        TVDevice(name: "Bravia", host: "192.168.1.50", port: 80)
    }

    // MARK: - Connection lifecycle

    func testConnect_setsCurrentDeviceAndConnectedState() async throws {
        let (adapter, _) = makeAdapter()
        XCTAssertEqual(adapter.currentState, .disconnected)
        XCTAssertNil(adapter.currentDevice)

        try await adapter.connect(to: sampleDevice)

        XCTAssertEqual(adapter.currentDevice, sampleDevice)
        XCTAssertEqual(adapter.currentState, .connected)
    }

    func testDisconnect_clearsDeviceAndDisconnectedState() async throws {
        let (adapter, _) = makeAdapter()
        try await adapter.connect(to: sampleDevice)
        adapter.disconnect()

        XCTAssertNil(adapter.currentDevice)
        XCTAssertEqual(adapter.currentState, .disconnected)
    }

    func testConnectionStatePublisher_emitsDisconnectedThenConnectedOnConnect() async throws {
        let (adapter, _) = makeAdapter()
        var received: [ConnectionState] = []
        let sub = adapter.connectionState.sink { received.append($0) }

        try await adapter.connect(to: sampleDevice)
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(received.last, .connected)
        sub.cancel()
    }

    // MARK: - Unsupported actions (no IRCC mapping)

    func testSend_textInput_throwsDeviceUnreachable() async throws {
        let (adapter, _) = makeAdapter()
        do {
            try await adapter.send(.textInput("hi"))
            XCTFail("expected error")
        } catch let error as ConnectionError {
            XCTAssertEqual(error, .deviceUnreachable)
        }
    }

    func testSend_deleteCharacter_enter_openApp_throwsDeviceUnreachable() async throws {
        let (adapter, _) = makeAdapter()
        for action: RemoteAction in [.deleteCharacter, .enter, .openApp("https://example.com")] {
            do {
                try await adapter.send(action)
                XCTFail("expected error for \(action)")
            } catch let error as ConnectionError {
                XCTAssertEqual(error, .deviceUnreachable, "action \(action)")
            }
        }
    }

    func testSend_rewind_fastForward_throwsDeviceUnreachable() async throws {
        let (adapter, _) = makeAdapter()
        MockURLSession.requestHandler = { _ in
            XCTFail("network should not be called when IRCC code is nil")
            throw URLError(.unknown)
        }

        for action: RemoteAction in [.rewind, .fastForward] {
            do {
                try await adapter.send(action)
                XCTFail("expected error for \(action)")
            } catch let error as ConnectionError {
                XCTAssertEqual(error, .deviceUnreachable)
            }
        }
    }

    // MARK: - Supported actions → IRCC (mocked HTTP)

    /// IRCC base64 codes must match `SonyBraviaIRCC.getIRCCCode(for:)`.
    private static let supportedActionIRCCPairs: [(RemoteAction, String)] = [
        (.dpadUp, "AAAAAQAAAAEAAAB0Aw=="),
        (.dpadDown, "AAAAAQAAAAEAAAB1Aw=="),
        (.dpadLeft, "AAAAAQAAAAEAAAB3Aw=="),
        (.dpadRight, "AAAAAQAAAAEAAAB2Aw=="),
        (.dpadCenter, "AAAAAQAAAAEAAABlAw=="),
        (.home, "AAAAAQAAAAEAAABgAw=="),
        (.back, "AAAAAgAAAJcAAAAjAw=="),
        (.menu, "AAAAAQAAAAEAAAAbAw=="),
        (.playPause, "AAAAAQAAAAEAAABlAw=="),
        (.play, "AAAAAQAAAAEAAABkAw=="),
        (.pause, "AAAAAQAAAAEAAABlAw=="),
        (.stop, "AAAAAQAAAAEAAABjAw=="),
        (.next, "AAAAAQAAAAEAAABgAw=="),
        (.previous, "AAAAAQAAAAEAAABhAw=="),
        (.volumeUp, "AAAAAQAAAAEAAABRAw=="),
        (.volumeDown, "AAAAAQAAAAEAAABSAw=="),
        (.mute, "AAAAAQAAAAEAAAAUAw=="),
        (.power, "AAAAAQAAAAEAAAAVAw=="),
    ]

    func testSend_allMappedActions_postExpectedIRCCCode() async throws {
        let (adapter, _) = makeAdapter()
        var callIndex = 0
        let pairs = Self.supportedActionIRCCPairs

        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertTrue(url.absoluteString.contains("/sony/IRCC"))
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Auth-PSK"), "0000")

            let pair = pairs[callIndex]
            callIndex += 1
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            XCTAssertTrue(
                body.contains("<IRCCCode>\(pair.1)</IRCCCode>"),
                "action index \(callIndex - 1) expected IRCC \(pair.1)"
            )

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        for (action, _) in pairs {
            try await adapter.send(action)
        }

        XCTAssertEqual(callIndex, pairs.count)
    }

    func testSend_withKeyPressDirection_usesSamePathAsShortPress() async throws {
        let (adapter, _) = makeAdapter()
        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("<IRCCCode>AAAAAQAAAAEAAABgAw==</IRCCCode>"))
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        try await adapter.send(.home, direction: .startLong)
        try await adapter.send(.home, direction: .endLong)
    }

    func testSend_irccHttpError_surfacesSonyBraviaError() async throws {
        let (adapter, _) = makeAdapter()
        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 502, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            try await adapter.send(.mute)
            XCTFail("expected error")
        } catch let error as SonyBraviaError {
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 502)
            } else {
                XCTFail("wrong error \(error)")
            }
        }
    }

    // MARK: - Pairing

    func testStartPairing_actRegisterSuccess_setsWaitingForCode() async throws {
        let (adapter, _) = makeAdapter()
        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertTrue(url.path.contains("/sony/accessControl"))
            let bodyData = try XCTUnwrap(request.httpBody)
            let obj = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertEqual(obj?["method"] as? String, "actRegister")

            let json = #"{"result":[],"id":1}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        try await adapter.startPairing(to: sampleDevice)

        XCTAssertEqual(adapter.currentDevice, sampleDevice)
        XCTAssertEqual(adapter.currentState, .pairing(.waitingForCode))
    }

    func testStartPairing_whenRESTEventuallyFails_mapsToPairingFailed() async throws {
        let (adapter, _) = makeAdapter()
        // JSON-RPC error causes actRegister to retry all payload/PSK combinations; final failure is a REST error.
        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let json = #"{"error":[403,"denied"],"id":1}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        do {
            try await adapter.startPairing(to: sampleDevice)
            XCTFail("expected error")
        } catch let error as ConnectionError {
            if case .pairingFailed(let message) = error {
                XCTAssertFalse(message.isEmpty)
                XCTAssertTrue(
                    message.contains("401") || message.contains("denied") || message.contains("TV settings"),
                    "unexpected message: \(message)"
                )
            } else {
                XCTFail("wrong error \(error)")
            }
        }
    }

    func testSubmitPairingCode_invalidLength_throwsPairingFailed() async throws {
        let (adapter, _) = makeAdapter()
        for invalid in ["12", "12345", "1234567", "12ab", ""] {
            do {
                try await adapter.submitPairingCode(invalid)
                XCTFail("expected failure for \(invalid)")
            } catch let error as ConnectionError {
                if case .pairingFailed(let message) = error {
                    XCTAssertTrue(message.contains("PIN") || message.contains("digit"))
                } else {
                    XCTFail("wrong error \(error)")
                }
            }
        }
    }

    func testSubmitPairingCode_nonNumeric_throwsPairingFailed() async throws {
        let (adapter, _) = makeAdapter()
        do {
            try await adapter.submitPairingCode("12345a")
            XCTFail("expected error")
        } catch let error as ConnectionError {
            if case .pairingFailed(let message) = error {
                XCTAssertTrue(message.contains("PIN") || message.contains("digit"))
            } else {
                XCTFail("wrong error \(error)")
            }
        }
    }

    func testSubmitPairingCode_withoutPriorPairing_throws() async throws {
        let (adapter, _) = makeAdapter()
        do {
            try await adapter.submitPairingCode("123456")
            XCTFail("expected error")
        } catch let error as ConnectionError {
            if case .pairingFailed(let message) = error {
                XCTAssertTrue(message.contains("pairing") || message.contains("session"))
            } else {
                XCTFail("wrong error \(error)")
            }
        }
    }

    func testSubmitPairingCode_success_setsConnected_andPropagatesCookieToIRCC() async throws {
        let (adapter, _) = makeAdapter(host: "10.0.0.99")
        let device = TVDevice(name: "Sony", host: "10.0.0.99", port: 80)

        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let jsonOK = #"{"result":[],"id":1}"#.data(using: .utf8)!

            if url.path.contains("/sony/accessControl") {
                let isPinSubmit = request.value(forHTTPHeaderField: "Authorization") != nil
                if isPinSubmit {
                    let fields = ["Set-Cookie": "bravia=token123; Path=/"]
                    let response = HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: fields
                    )!
                    return (response, jsonOK)
                }
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, jsonOK)
            }

            if url.absoluteString.contains("/sony/IRCC") {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "bravia=token123")
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }

            XCTFail("unexpected URL \(url)")
            throw URLError(.badURL)
        }

        try await adapter.startPairing(to: device)
        XCTAssertEqual(adapter.currentState, .pairing(.waitingForCode))

        try await adapter.submitPairingCode("654321")
        XCTAssertEqual(adapter.currentState, .connected)

        try await adapter.send(.power)
    }

    func testSubmitPairingCode_pinSubmissionHttpError_wrapsPairingFailed() async throws {
        let (adapter, _) = makeAdapter()
        var accessCallCount = 0

        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            accessCallCount += 1

            if accessCallCount == 1 {
                let json = #"{"result":[],"id":1}"#.data(using: .utf8)!
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, json)
            }

            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        try await adapter.startPairing(to: sampleDevice)

        do {
            try await adapter.submitPairingCode("123456")
            XCTFail("expected error")
        } catch let error as ConnectionError {
            if case .pairingFailed(let message) = error {
                XCTAssertTrue(message.contains("PIN") || message.contains("401") || message.contains("failed"))
            } else {
                XCTFail("wrong error \(error)")
            }
        }
    }

    func testAcceptsFourDigitPIN() async throws {
        let (adapter, _) = makeAdapter()
        var accessCallCount = 0

        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            accessCallCount += 1
            let json = #"{"result":[],"id":1}"#.data(using: .utf8)!

            if accessCallCount == 1 {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, json)
            }

            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            XCTAssertTrue(auth.hasPrefix("Basic "))
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        try await adapter.startPairing(to: sampleDevice)
        try await adapter.submitPairingCode("4242")
        XCTAssertEqual(adapter.currentState, .connected)
    }
}
