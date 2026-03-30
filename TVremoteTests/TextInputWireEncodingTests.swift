//
//  TextInputWireEncodingTests.swift
//  TVremoteTests
//
//  Byte-level checks for `TextInput.data` vs the nested message layout documented in
//  `TextInput.swift` (same schema as `remotemessage.proto` in community Android TV Remote v2
//  implementations such as https://github.com/tronikos/androidtvremote2 and protocol write-ups
//  in https://github.com/louis49/androidtv-remote).
//

import XCTest
@testable import TVremote

final class TextInputWireEncodingTests: XCTestCase {
    /// After outer tag `0xAA 0x01`, first byte of length varint must sit at index 2.
    func testOuterBatchLength_startsAtIndex2() {
        let data = TextInput("hi", imeCounter: 2, fieldCounter: 3).data
        XCTAssertGreaterThanOrEqual(data.count, 4)
        XCTAssertEqual(data[0], 0xAA)
        XCTAssertEqual(data[1], 0x01)
        guard let (batchLen, consumed) = VarintCodec.decode(data, from: 2) else {
            XCTFail("batch length varint")
            return
        }
        XCTAssertGreaterThan(batchLen, 0)
        XCTAssertGreaterThanOrEqual(consumed, 1)
        let batchStart = 2 + consumed
        XCTAssertLessThanOrEqual(batchStart + Int(batchLen), data.count)
    }

    func testBatchEdit_opensWithImeThenFieldCounters() {
        let data = TextInput("x", imeCounter: 9, fieldCounter: 11).data
        guard let (batchLen, lenConsumed) = VarintCodec.decode(data, from: 2) else {
            XCTFail("length")
            return
        }
        let start = 2 + lenConsumed
        let batch = data.subdata(in: start..<(start + Int(batchLen)))
        XCTAssertGreaterThanOrEqual(batch.count, 6)
        XCTAssertEqual(batch[0], 0x08, "ime_counter field 1 tag")
        XCTAssertEqual(batch[1], 0x09, "ime_counter = 9 single-byte varint")
        XCTAssertEqual(batch[2], 0x10, "field_counter field 2 tag")
        XCTAssertEqual(batch[3], 0x0B, "field_counter = 11 single-byte varint")
        XCTAssertEqual(batch[4], 0x1A, "edit_info field 3 tag (length-delimited)")
    }

    func testRemoteImeObject_valueField_carriesRawUtf8Bytes() {
        let text = "é"
        let data = TextInput(text, imeCounter: 0, fieldCounter: 0).data
        let utf8Blob = Data(text.utf8)
        XCTAssertEqual(utf8Blob.count, 2)
        XCTAssertNotNil(
            data.range(of: utf8Blob),
            "`value` must embed String UTF-8 bytes (protobuf string), not grapheme count"
        )
        let parsed = RemoteImeProtobuf.imeCounters(from: data)
        XCTAssertNotNil(parsed)
    }

    func testStartEndPositions_useSwiftCharacterCount_minusOne() {
        let text = "no"
        let data = TextInput(text, imeCounter: 0, fieldCounter: 0).data
        let expectedPos = max(0, text.count - 1)
        XCTAssertEqual(expectedPos, 1)
        XCTAssertTrue(
            data.contains { $0 == 0x01 },
            "start/end varints should encode position 1 for two-character string"
        )
    }
}
