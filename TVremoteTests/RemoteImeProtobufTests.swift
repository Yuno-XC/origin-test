//
//  RemoteImeProtobufTests.swift
//  TVremoteTests
//
//  Edge cases for `RemoteImeProtobuf.imeCounters` beyond `TextInput` round-trips.
//

import XCTest
@testable import TVremote

final class RemoteImeProtobufTests: XCTestCase {
    func testImeCounters_dataTooShort_returnsNil() {
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data()))
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data([0xAA])))
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data([0xAA, 0x01, 0x01])))
    }

    func testImeCounters_noField21Marker_returnsNil() {
        let data = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05])
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: data))
    }

    func testImeCounters_truncatedLengthAfterTag_returnsNil() {
        // Tag 0xAA 0x01 then varint length would extend past buffer
        var bytes: [UInt8] = [0xAA, 0x01, 0x80, 0x80, 0x01]
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(bytes)))
    }

    func testImeCounters_innerBatchMissingField_returnsNil() {
        // Outer field 21 with length 1 byte of garbage (no ime_counter / field_counter pair)
        let bytes: [UInt8] = [0xAA, 0x01, 0x01, 0xFF]
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(bytes)))
    }

    func testImeCounters_findsMarkerAfterLeadingNoise() {
        let inner: [UInt8] = [0x08, 0x03, 0x10, 0x04]
        var outer: [UInt8] = [0x01, 0x02, 0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        let parsed = RemoteImeProtobuf.imeCounters(from: Data(outer))
        XCTAssertEqual(parsed?.imeCounter, 3)
        XCTAssertEqual(parsed?.fieldCounter, 4)
    }
}
