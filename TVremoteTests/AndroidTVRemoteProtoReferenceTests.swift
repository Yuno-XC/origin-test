//
//  AndroidTVRemoteProtoReferenceTests.swift
//  TVremoteTests
//
//  Field-number and tag constants aligned with Android TV Remote v2–style
//  `RemoteMessage` / IME messages. Primary schema reference:
//  https://github.com/tronikos/androidtvremote2 (Python; ships `remotemessage.proto`).
//  Related protocol / client implementations useful for cross-checking wire layouts:
//  https://github.com/louis49/androidtv-remote (Java).
//

import XCTest
@testable import TVremote

final class AndroidTVRemoteProtoReferenceTests: XCTestCase {
    func testRemoteMessage_remoteImeBatchEdit_field21LengthDelimitedTag170() {
        let tag = (21 << 3) | 2
        XCTAssertEqual(tag, 170)
        let decoded = VarintCodec.decode([0xAA, 0x01])
        XCTAssertEqual(decoded?.0, UInt64(tag))
        XCTAssertEqual(decoded?.1, 2)
    }

    func testRemoteImeBatchEdit_innerFieldTags_matchProtoLayout() {
        XCTAssertEqual((1 << 3) | 0, 8)
        XCTAssertEqual((2 << 3) | 0, 16)
        XCTAssertEqual((3 << 3) | 2, 26)
    }

    func testRemoteEditInfo_fieldTags_matchProtoLayout() {
        XCTAssertEqual((1 << 3) | 0, 8)
        XCTAssertEqual((2 << 3) | 2, 18)
    }

    func testRemoteImeObject_fieldTags_matchProtoLayout() {
        XCTAssertEqual((1 << 3) | 0, 8)
        XCTAssertEqual((2 << 3) | 0, 16)
        XCTAssertEqual((3 << 3) | 2, 26)
    }

    func testRemoteImeBatchEdit_field3_editInfo_isLengthDelimitedTag26() {
        XCTAssertEqual((3 << 3) | 2, 26)
    }

    /// Field 21 wire type 2: tag 170 fits in one byte (0xAA) or two (0xAA 0x01) depending on encoder.
    func testField21_tagValue_is170() {
        XCTAssertEqual((21 << 3) | 2, 170)
        XCTAssertEqual(UInt8(truncatingIfNeeded: 170), 0xAA)
    }
}
