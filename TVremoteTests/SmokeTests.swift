//
//  SmokeTests.swift
//  TVremoteTests
//
//  Lightweight sanity checks for the test target (CI / local verification).
//

import XCTest

final class SmokeTests: XCTestCase {
    func test_bundleLoads() {
        let bundle = Bundle(for: SmokeTests.self)
        XCTAssertNotNil(bundle.bundleIdentifier)
    }
}
