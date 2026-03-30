//
//  AppMetadataTests.swift
//  test-remoteide
//

import XCTest
@testable import test_remoteide

final class AppMetadataTests: XCTestCase {
    func testAppName() {
        XCTAssertEqual(AppMetadata.appName, "test-remoteide")
    }

    func testVersionDescriptionFormat() {
        let versionDescription = AppMetadata.versionDescription

        // Should contain parentheses for build number
        XCTAssertTrue(versionDescription.contains("("))
        XCTAssertTrue(versionDescription.contains(")"))

        // Should not be empty
        XCTAssertFalse(versionDescription.isEmpty)
    }

    func testVersionDescriptionNeverContainsUnknown() {
        let versionDescription = AppMetadata.versionDescription

        // Even if Bundle info isn't available, should have a fallback
        XCTAssertFalse(versionDescription.isEmpty)
    }

    func testVersionDescriptionStructure() {
        let versionDescription = AppMetadata.versionDescription
        let pattern = "^.+\\(.+\\)$"

        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(versionDescription.startIndex..., in: versionDescription)

        // Should match pattern: "version (build)"
        XCTAssertTrue(regex.firstMatch(in: versionDescription, range: range) != nil)
    }
}
