//
//  TextInputProtobufTests.swift
//  TVremoteTests
//
//  Validates `TextInput.data` against the same wire layout as `RemoteImeProtobuf` / Android TV
//  RemoteMessage.field 21. Public reference: `remotemessage.proto` in
//  https://github.com/tronikos/androidtvremote2 (see `TextInput.swift` comments).
//

import XCTest
@testable import TVremote

final class TextInputProtobufTests: XCTestCase {
    func testRoundTrip_remoteImeProtobufExtractsCounters() {
        let input = TextInput("hello", imeCounter: 11, fieldCounter: 22)
        let parsed = RemoteImeProtobuf.imeCounters(from: input.data)
        XCTAssertEqual(parsed?.imeCounter, 11)
        XCTAssertEqual(parsed?.fieldCounter, 22)
    }

    func testRoundTrip_emptyString_extractsCounters() {
        let input = TextInput("", imeCounter: 0, fieldCounter: 0)
        let parsed = RemoteImeProtobuf.imeCounters(from: input.data)
        XCTAssertEqual(parsed?.imeCounter, 0)
        XCTAssertEqual(parsed?.fieldCounter, 0)
    }

    func testWireLayout_outerFieldTag_is170EncodedAsAA01() {
        let data = TextInput("x", imeCounter: 1, fieldCounter: 1).data
        XCTAssertGreaterThanOrEqual(data.count, 4)
        XCTAssertEqual(data[0], 0xAA)
        XCTAssertEqual(data[1], 0x01)
    }

    func testRoundTrip_largeCounters_multibyteVarints() {
        let input = TextInput("a", imeCounter: 300, fieldCounter: 16_384)
        let parsed = RemoteImeProtobuf.imeCounters(from: input.data)
        XCTAssertEqual(parsed?.imeCounter, 300)
        XCTAssertEqual(parsed?.fieldCounter, 16_384)
    }

    func testUtf8Text_roundTripCountersPreserved() {
        let input = TextInput("café 🎬", imeCounter: 7, fieldCounter: 8)
        let parsed = RemoteImeProtobuf.imeCounters(from: input.data)
        XCTAssertEqual(parsed?.imeCounter, 7)
        XCTAssertEqual(parsed?.fieldCounter, 8)
    }

    /// Large inner `RemoteImeBatchEdit` forces a multi-byte length varint after tag `0xAA 0x01`, matching varint-walking parsers used in open-source Android TV remote stacks.
    func testLongText_outerBatchLength_usesMultiByteVarint() {
        let longText = String(repeating: "z", count: 400)
        let input = TextInput(longText, imeCounter: 3, fieldCounter: 4)
        let data = input.data
        guard let (batchLen, consumed) = VarintCodec.decode(data, from: 2) else {
            XCTFail("batch length varint")
            return
        }
        XCTAssertGreaterThanOrEqual(batchLen, 128)
        XCTAssertGreaterThanOrEqual(consumed, 2)
        let parsed = RemoteImeProtobuf.imeCounters(from: data)
        XCTAssertEqual(parsed?.imeCounter, 3)
        XCTAssertEqual(parsed?.fieldCounter, 4)
    }

    func testEmptyText_stillEmbedsRemoteImeObjectWithEmptyString() {
        let input = TextInput("", imeCounter: 0, fieldCounter: 0)
        let data = input.data
        XCTAssertNotNil(RemoteImeProtobuf.imeCounters(from: data))
        XCTAssertTrue(data.contains(0x1A), "RemoteImeObject.value (field 3) is length-delimited tag 26")
    }

    /// `TextInput` uses `Swift.String.count` for start/end (grapheme clusters), not UTF-8 byte length.
    func testSingleCharacter_startEndVarintsAreZero() {
        let data = TextInput("x", imeCounter: 0, fieldCounter: 0).data
        XCTAssertTrue(
            data.contains(Data([0x08, 0x00])),
            "RemoteImeObject.start = max(0, count - 1) = 0"
        )
        XCTAssertTrue(data.contains(Data([0x10, 0x00])), "RemoteImeObject.end matches start for one character")
    }

    func testEmoji_usesCharacterCountForStartEnd_notScalarCount() {
        let text = "👨‍👩‍👧"
        let data = TextInput(text, imeCounter: 1, fieldCounter: 1).data
        let expectedPos = max(0, text.count - 1)
        XCTAssertEqual(expectedPos, 0, "one extended grapheme cluster → start/end 0")
        XCTAssertTrue(data.contains(Data([0x08, 0x00])))
        XCTAssertTrue(data.contains(Data([0x10, 0x00])))
    }
}
