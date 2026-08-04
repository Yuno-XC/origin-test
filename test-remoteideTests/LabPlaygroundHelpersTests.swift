//
//  LabPlaygroundHelpersTests.swift
//  test-remoteide
//

import XCTest
import SwiftUI
@testable import test_remoteide

final class PreviewLayoutResolverTests: XCTestCase {
    func testAdaptiveUsesVerticalWhenWidthLessThanThreshold() {
        XCTAssertTrue(
            PreviewLayoutResolver.shouldUseVerticalLayout(.adaptive, width: 100, height: 120)
        )
    }

    func testAdaptiveUsesHorizontalWhenWideEnough() {
        XCTAssertFalse(
            PreviewLayoutResolver.shouldUseVerticalLayout(.adaptive, width: 200, height: 100)
        )
    }

    func testAdaptiveBoundaryWidthEqualsHeightTimes092() {
        let h: CGFloat = 100
        let w = h * 0.92
        XCTAssertFalse(PreviewLayoutResolver.shouldUseVerticalLayout(.adaptive, width: w, height: h))
        XCTAssertTrue(PreviewLayoutResolver.shouldUseVerticalLayout(.adaptive, width: w - 0.01, height: h))
    }

    func testHorizontalNeverVertical() {
        XCTAssertFalse(
            PreviewLayoutResolver.shouldUseVerticalLayout(.horizontal, width: 10, height: 500)
        )
    }

    func testVerticalAlwaysVertical() {
        XCTAssertTrue(
            PreviewLayoutResolver.shouldUseVerticalLayout(.vertical, width: 500, height: 10)
        )
    }
}

final class LabSnapshotNamingTests: XCTestCase {
    func testDefaultUntitledName() {
        XCTAssertEqual(LabSnapshotNaming.defaultUntitledName(savedSnapshotCount: 0), "Snapshot 1")
        XCTAssertEqual(LabSnapshotNaming.defaultUntitledName(savedSnapshotCount: 3), "Snapshot 4")
    }

    func testDuplicateNameWhenFirstCopyIsFree() {
        let name = LabSnapshotNaming.nextDuplicateName(
            baseName: "A",
            existingNames: []
        )
        XCTAssertEqual(name, "A Copy")
    }

    func testDuplicateNameSkipsFirstWhenTaken() {
        let name = LabSnapshotNaming.nextDuplicateName(
            baseName: "Preset",
            existingNames: ["Preset Copy"]
        )
        XCTAssertEqual(name, "Preset Copy 2")
    }

    func testDuplicateNameIncrementsUntilFree() {
        let name = LabSnapshotNaming.nextDuplicateName(
            baseName: "X",
            existingNames: ["X Copy", "X Copy 2", "X Copy 3"]
        )
        XCTAssertEqual(name, "X Copy 4")
    }

    func testDuplicateNameDoesNotCollideWithGapInNumbers() {
        let name = LabSnapshotNaming.nextDuplicateName(
            baseName: "Y",
            existingNames: ["Y Copy", "Y Copy 3"]
        )
        XCTAssertEqual(name, "Y Copy 2")
    }
}
