//
//  DiscoveryErrorTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

final class DiscoveryErrorTests: XCTestCase {
    func testDiscoveryError_descriptions() {
        XCTAssertEqual(DiscoveryError.invalidAddress.errorDescription, "Invalid IP address")
        XCTAssertEqual(DiscoveryError.networkUnavailable.errorDescription, "Network unavailable")
        XCTAssertEqual(DiscoveryError.timeout.errorDescription, "Discovery timed out")
    }
}
