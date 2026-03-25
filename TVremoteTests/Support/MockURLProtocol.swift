//
//  MockURLProtocol.swift
//  TVremoteTests
//

import Foundation

enum MockURLSession {
    /// Set before each request when using `makeEphemeralSession()`; clear in `tearDown`.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?
}

final class MockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        MockURLSession.requestHandler != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLSession.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeEphemeralSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
