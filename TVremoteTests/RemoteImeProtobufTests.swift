//
//  RemoteImeProtobufTests.swift
//  TVremoteTests
//
//  Covers protobuf field 21 (RemoteImeBatchEdit) scanning — same wire layout as Android TV Remote IME batches.
//

import XCTest
@testable import TVremote

final class RemoteImeProtobufTests: XCTestCase {
    /// Field 21 tag (170) as two-byte varint, length 4, inner: ime=5 (field 1), field=7 (field 2).
    private let minimalValid: [UInt8] = [0xAA, 0x01, 0x04, 0x08, 0x05, 0x10, 0x07]

    func testImeCounters_minimalPayload() {
        let r = RemoteImeProtobuf.imeCounters(from: Data(minimalValid))
        XCTAssertEqual(r?.imeCounter, 5)
        XCTAssertEqual(r?.fieldCounter, 7)
    }

    func testImeCounters_emptyData_returnsNil() {
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data()))
    }

    func testImeCounters_oneOrTwoBytes_returnsNil() {
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data([0xAA])))
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data([0xAA, 0x01])))
    }

    func testImeCounters_threeBytes_returnsNil() {
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data([0x01, 0x02, 0x03])))
    }

    func testImeCounters_findsTagAfterGarbagePrefix() {
        var buf = [UInt8](repeating: 0x11, count: 5)
        buf.append(contentsOf: minimalValid)
        let r = RemoteImeProtobuf.imeCounters(from: Data(buf))
        XCTAssertEqual(r?.imeCounter, 5)
        XCTAssertEqual(r?.fieldCounter, 7)
    }

    func testImeCounters_tooShort_returnsNil() {
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data([0xAA, 0x01, 0x01])))
    }

    func testImeCounters_noTag_returnsNil() {
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data([0x01, 0x02, 0x03, 0x04])))
    }

    func testImeCounters_truncatedInnerLength_returnsNil() {
        // Tag + length 4 but only 2 payload bytes
        let bad: [UInt8] = [0xAA, 0x01, 0x04, 0x08, 0x05]
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(bad)))
    }

    func testImeCounters_invalidLengthVarintAfterTag_returnsNil() {
        var buf: [UInt8] = [0xAA, 0x01]
        buf.append(contentsOf: [UInt8](repeating: 0xFF, count: 12))
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(buf)))
    }

    func testImeCounters_onlyImeCounter_returnsNil() {
        // Inner: only field 1 = 5 (missing field 2)
        let inner: [UInt8] = [0x08, 0x05]
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(outer)))
    }

    func testImeCounters_skipsLengthDelimitedInnerField() {
        // Field 3, wire 2: tag 0x1A, len 2, payload 0x11 0x22, then ime and field counters
        let inner: [UInt8] = [0x1A, 0x02, 0x11, 0x22, 0x08, 0x09, 0x10, 0x03]
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        let r = RemoteImeProtobuf.imeCounters(from: Data(outer))
        XCTAssertEqual(r?.imeCounter, 9)
        XCTAssertEqual(r?.fieldCounter, 3)
    }

    func testImeCounters_skipsUnknownVarintField() {
        // Field 4 varint value 1: tag (4<<3)|0 = 32 = 0x20, value 0x01
        let inner: [UInt8] = [0x20, 0x01, 0x08, 0x02, 0x10, 0x04]
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        let r = RemoteImeProtobuf.imeCounters(from: Data(outer))
        XCTAssertEqual(r?.imeCounter, 2)
        XCTAssertEqual(r?.fieldCounter, 4)
    }

    func testImeCounters_unknownWireType_returnsNil() {
        // Field 1 with wire type 1 (64-bit): tag (1<<3)|1 = 0x09, then 8 bytes
        let inner: [UInt8] = [0x09] + [UInt8](repeating: 0, count: 8)
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(outer)))
    }

    func testImeCounters_reorderedFields_stillExtracts() {
        // field_counter before ime_counter
        let inner: [UInt8] = [0x10, 0x0C, 0x08, 0x0D]
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        let r = RemoteImeProtobuf.imeCounters(from: Data(outer))
        XCTAssertEqual(r?.imeCounter, 13)
        XCTAssertEqual(r?.fieldCounter, 12)
    }

    func testImeCounters_innerLengthZero_returnsNil() {
        let outer: [UInt8] = [0xAA, 0x01, 0x00]
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(outer)))
    }

    func testImeCounters_usesFirstField21Match() {
        let secondInner: [UInt8] = [0x08, 0x01, 0x10, 0x02]
        var second: [UInt8] = [0xAA, 0x01, UInt8(secondInner.count)]
        second.append(contentsOf: secondInner)
        var buf = minimalValid
        buf.append(contentsOf: second)
        let r = RemoteImeProtobuf.imeCounters(from: Data(buf))
        XCTAssertEqual(r?.imeCounter, 5)
        XCTAssertEqual(r?.fieldCounter, 7)
    }

    func testImeCounters_skips32BitFixedInnerField() {
        // Field 5 wire type 5 (32-bit): tag (5<<3)|5 = 45 = 0x2D, then 4 bytes
        let inner: [UInt8] = [0x2D] + [UInt8](repeating: 0x00, count: 4) + [0x08, 0x03, 0x10, 0x04]
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(outer)))
    }

    /// Outer length > 127 uses a multi-byte varint (same as Swift protobuf / GitHub reference decoders).
    func testImeCounters_multiByteOuterLengthVarint() {
        let suffix: [UInt8] = [0x08, 0x05, 0x10, 0x07]
        let padLen = 126
        var inner: [UInt8] = [0x4A, UInt8(padLen)]
        inner.append(contentsOf: [UInt8](repeating: 0x00, count: padLen))
        inner.append(contentsOf: suffix)
        XCTAssertEqual(inner.count, 132)

        var outer: [UInt8] = [0xAA, 0x01, 0x84, 0x01]
        outer.append(contentsOf: inner)
        let r = RemoteImeProtobuf.imeCounters(from: Data(outer))
        XCTAssertEqual(r?.imeCounter, 5)
        XCTAssertEqual(r?.fieldCounter, 7)
    }

    func testImeCounters_findsTagAfterFalseAAPrefix() {
        var buf: [UInt8] = [0xAA, 0x00, 0x01]
        buf.append(contentsOf: minimalValid)
        let r = RemoteImeProtobuf.imeCounters(from: Data(buf))
        XCTAssertEqual(r?.imeCounter, 5)
        XCTAssertEqual(r?.fieldCounter, 7)
    }

    func testImeCounters_innerWireTypeStartGroup_returnsNil() {
        // Field 1, wire type 3 (start group): tag (1<<3)|3 = 0x0B
        let inner: [UInt8] = [0x0B, 0x00, 0x00, 0x00, 0x00]
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(outer)))
    }

    func testImeCounters_innerTruncatedAfterTag_returnsNil() {
        let inner: [UInt8] = [0x08]
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(outer)))
    }

    /// `edit_info` (field 3) may appear before counters in wire order; parser skips length-delimited fields.
    func testImeCounters_editInfoFieldBeforeCounters_stillExtracts() {
        let editChunk: [UInt8] = [0x1A, 0x02, 0x08, 0x01] // field 3, len 2: insert=1
        let counterChunk: [UInt8] = [0x08, 0x0E, 0x10, 0x0F] // ime=14, field=15
        let inner = editChunk + counterChunk
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        let r = RemoteImeProtobuf.imeCounters(from: Data(outer))
        XCTAssertEqual(r?.imeCounter, 14)
        XCTAssertEqual(r?.fieldCounter, 15)
    }

    /// Valid protobuf could use one byte for tag 170 (`0xAA`) then length; our scanner only locks onto `0xAA 0x01` (matches `TextInput` and common two-byte tag encodings).
    func testImeCounters_singleByteTag170_notMatched_withoutSecondByte() {
        let inner: [UInt8] = [0x08, 0x03, 0x10, 0x04]
        var outer: [UInt8] = [UInt8(170), UInt8(inner.count)]
        outer.append(contentsOf: inner)
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(outer)))
    }

    /// Wire type 4 (end group) is unsupported; parser bails on unknown wire kinds.
    func testImeCounters_innerWireTypeEndGroup_returnsNil() {
        let inner: [UInt8] = [0x0C, 0x00, 0x00, 0x00]
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        XCTAssertNil(RemoteImeProtobuf.imeCounters(from: Data(outer)))
    }

    /// If the inner message repeats field 1, the last varint wins (typical protobuf merge semantics for scalars).
    func testImeCounters_duplicateImeCounter_lastValueWins() {
        let inner: [UInt8] = [0x08, 0x01, 0x08, 0x02, 0x10, 0x03]
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        let r = RemoteImeProtobuf.imeCounters(from: Data(outer))
        XCTAssertEqual(r?.imeCounter, 2)
        XCTAssertEqual(r?.fieldCounter, 3)
    }

    func testImeCounters_duplicateFieldCounter_lastValueWins() {
        let inner: [UInt8] = [0x08, 0x0A, 0x10, 0x01, 0x10, 0x02]
        var outer: [UInt8] = [0xAA, 0x01, UInt8(inner.count)]
        outer.append(contentsOf: inner)
        let r = RemoteImeProtobuf.imeCounters(from: Data(outer))
        XCTAssertEqual(r?.imeCounter, 10)
        XCTAssertEqual(r?.fieldCounter, 2)
    }
}
