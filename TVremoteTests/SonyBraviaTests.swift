//
//  SonyBraviaTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

final class SonyBraviaTests: XCTestCase {
    override func tearDown() {
        MockURLSession.requestHandler = nil
        super.tearDown()
    }

    // MARK: - SonyBraviaError

    func testSonyBraviaError_errorDescriptions() {
        XCTAssertEqual(SonyBraviaError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(SonyBraviaError.invalidResponse.errorDescription, "Invalid response from TV")
        XCTAssertEqual(SonyBraviaError.httpError(503).errorDescription, "HTTP error: 503")
        XCTAssertEqual(SonyBraviaError.unsupportedCommand.errorDescription, "Unsupported command")
        XCTAssertEqual(
            SonyBraviaError.restAPIError(code: 12, message: "nope").errorDescription,
            "REST API error 12: nope"
        )
    }

    // MARK: - IRCC mapping

    func testSonyBraviaIRCC_getIRCCCode_mapsNavigationAndMedia() {
        let ircc = SonyBraviaIRCC(host: "127.0.0.1")
        XCTAssertEqual(ircc.getIRCCCode(for: .home), "AAAAAQAAAAEAAABgAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .back), "AAAAAgAAAJcAAAAjAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .menu), "AAAAAQAAAAEAAAAbAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .dpadUp), "AAAAAQAAAAEAAAB0Aw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .dpadDown), "AAAAAQAAAAEAAAB1Aw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .dpadLeft), "AAAAAQAAAAEAAAB3Aw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .dpadRight), "AAAAAQAAAAEAAAB2Aw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .dpadCenter), "AAAAAQAAAAEAAABlAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .volumeUp), "AAAAAQAAAAEAAABRAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .volumeDown), "AAAAAQAAAAEAAABSAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .mute), "AAAAAQAAAAEAAAAUAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .digit0), "AAAAAQAAAAEAAAAJAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .digit1), "AAAAAQAAAAEAAAAAAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .digit9), "AAAAAQAAAAEAAAAIAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .power), "AAAAAQAAAAEAAAAVAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .mediaPlay), "AAAAAQAAAAEAAABkAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .mediaStop), "AAAAAQAAAAEAAABjAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .mediaNext), "AAAAAQAAAAEAAABgAw==")
        XCTAssertEqual(ircc.getIRCCCode(for: .mediaPrevious), "AAAAAQAAAAEAAABhAw==")
    }

    func testSonyBraviaIRCC_getIRCCCode_unsupportedKeysReturnNil() {
        let ircc = SonyBraviaIRCC(host: "127.0.0.1")
        XCTAssertNil(ircc.getIRCCCode(for: .mediaRewind))
        XCTAssertNil(ircc.getIRCCCode(for: .mediaFastForward))
    }

    func testSonyBraviaIRCC_getIRCCCode_playPauseAndPauseMatchDocumentedCodes() {
        let ircc = SonyBraviaIRCC(host: "127.0.0.1")
        let center = "AAAAAQAAAAEAAABlAw=="
        XCTAssertEqual(ircc.getIRCCCode(for: .mediaPlayPause), center)
        XCTAssertEqual(ircc.getIRCCCode(for: .mediaPause), center)
    }

    // MARK: - IRCC HTTP (mocked)

    func testSonyBraviaIRCC_sendIRCCCommand_success() async throws {
        let session = MockURLProtocol.makeEphemeralSession()
        MockURLSession.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Auth-PSK"), "abcd")
            let url = try XCTUnwrap(request.url)
            XCTAssertTrue(url.absoluteString.contains("/sony/IRCC"))
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("<IRCCCode>CODE</IRCCCode>"))
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let ircc = SonyBraviaIRCC(host: "192.168.0.10", port: 80, authKey: "abcd", urlSession: session)
        try await ircc.sendIRCCCommand("CODE")
    }

    func testSonyBraviaIRCC_sendIRCCCommand_includesCookieWhenSet() async throws {
        let session = MockURLProtocol.makeEphemeralSession()
        MockURLSession.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "auth=1")
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let ircc = SonyBraviaIRCC(host: "10.0.0.2", urlSession: session)
        ircc.setAuthCookie("auth=1")
        try await ircc.sendIRCCCommand("X")
    }

    func testSonyBraviaIRCC_sendIRCCCommand_httpError() async {
        let session = MockURLProtocol.makeEphemeralSession()
        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let ircc = SonyBraviaIRCC(host: "10.0.0.3", urlSession: session)
        do {
            try await ircc.sendIRCCCommand("X")
            XCTFail("expected error")
        } catch let error as SonyBraviaError {
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 503)
            } else {
                XCTFail("wrong error \(error)")
            }
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testSonyBraviaIRCC_clearAuthCookie() async throws {
        let session = MockURLProtocol.makeEphemeralSession()
        MockURLSession.requestHandler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let ircc = SonyBraviaIRCC(host: "10.0.0.4", urlSession: session)
        ircc.setAuthCookie("x=y")
        ircc.clearAuthCookie()
        try await ircc.sendIRCCCommand("Z")
    }

    // MARK: - REST (mocked)

    func testSonyBraviaREST_getRemoteDeviceSettings_success() async throws {
        let session = MockURLProtocol.makeEphemeralSession()
        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertTrue(url.path.contains("/sony/system"))
            let json = #"{"result":[{"device":"tv"}],"id":1}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let rest = SonyBraviaREST(host: "192.168.0.20", urlSession: session)
        let settings = try await rest.getRemoteDeviceSettings()
        XCTAssertEqual(settings.count, 1)
        XCTAssertEqual(settings.first?["device"] as? String, "tv")
    }

    func testSonyBraviaREST_sendRequest_jsonRpcError() async {
        let session = MockURLProtocol.makeEphemeralSession()
        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let json = #"{"error":[403,"nope"],"id":1}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let rest = SonyBraviaREST(host: "192.168.0.21", urlSession: session)
        do {
            _ = try await rest.getRemoteControllerInfo()
            XCTFail("expected error")
        } catch let error as SonyBraviaError {
            if case .restAPIError(let code, let message) = error {
                XCTAssertEqual(code, 403)
                XCTAssertEqual(message, "nope")
            } else {
                XCTFail("wrong error \(error)")
            }
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testSonyBraviaREST_sendRemoteControlCommand_success() async throws {
        let session = MockURLProtocol.makeEphemeralSession()
        MockURLSession.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertTrue(url.path.contains("/sony/IRCC"))
            let bodyObj = try JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any]
            XCTAssertEqual(bodyObj?["method"] as? String, "setIRCCCode")
            let json = #"{"result":[],"id":1}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let rest = SonyBraviaREST(host: "192.168.0.22", urlSession: session)
        try await rest.sendRemoteControlCommand(command: "AAAA")
    }

    // MARK: - SonyBraviaError

    func testSonyBraviaError_localizedDescription() {
        XCTAssertEqual(SonyBraviaError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(SonyBraviaError.invalidResponse.errorDescription, "Invalid response from TV")
        XCTAssertEqual(SonyBraviaError.httpError(418).errorDescription, "HTTP error: 418")
        XCTAssertEqual(SonyBraviaError.unsupportedCommand.errorDescription, "Unsupported command")
        XCTAssertEqual(
            SonyBraviaError.restAPIError(code: 1, message: "m").errorDescription,
            "REST API error 1: m"
        )
    }
}
