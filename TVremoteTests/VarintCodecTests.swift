//
//  VarintCodecTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

/// Protobuf-style unsigned LEB128 encoder for round-trip checks (same layout as common GitHub protobuf/Swift test helpers).
private func encodeProtobufVarint(_ value: UInt64) -> [UInt8] {
    var n = value
    var bytes: [UInt8] = []
    repeat {
        var byte = UInt8(truncatingIfNeeded: n & 0x7F)
        n >>= 7
        if n != 0 {
            byte |= 0x80
        }
        bytes.append(byte)
    } while n != 0
    return bytes
}

final class VarintCodecTests: XCTestCase {
    func testDecode_zero() {
        let r = VarintCodec.decode([0x00])
        XCTAssertEqual(r?.0, 0)
        XCTAssertEqual(r?.1, 1)
    }

    func testDecode_singleByte_max() {
        let r = VarintCodec.decode([0x7F])
        XCTAssertEqual(r?.0, 127)
        XCTAssertEqual(r?.1, 1)
    }

    func testDecode_twoBytes() {
        // 300 = 0xAC 0x02
        let r = VarintCodec.decode([0xAC, 0x02])
        XCTAssertEqual(r?.0, 300)
        XCTAssertEqual(r?.1, 2)
    }

    func testDecode_empty_returnsNil() {
        XCTAssertNil(VarintCodec.decode([]))
    }

    func testDecode_incomplete_returnsNil() {
        // continuation bit set forever (more than 10 bytes)
        let bytes = [UInt8](repeating: 0xFF, count: 12)
        XCTAssertNil(VarintCodec.decode(bytes))
    }

    func testDecode_fromOffset_skipsPrefix() {
        let bytes: [UInt8] = [0xFF, 0xAC, 0x02]
        let r = VarintCodec.decode(bytes, from: 1)
        XCTAssertEqual(r?.0, 300)
        XCTAssertEqual(r?.1, 2)
    }

    func testDecode_dataFromOffset() {
        var data = Data([0x00])
        data.append(contentsOf: [0xAC, 0x02])
        let r = VarintCodec.decode(data, from: 1)
        XCTAssertEqual(r?.0, 300)
        XCTAssertEqual(r?.1, 2)
    }

    func testDecode_128_usesTwoBytes() {
        // 128 = 0x80 0x01
        let r = VarintCodec.decode([0x80, 0x01])
        XCTAssertEqual(r?.0, 128)
        XCTAssertEqual(r?.1, 2)
    }

    func testDecode_startIndexAtEnd_returnsNil() {
        XCTAssertNil(VarintCodec.decode([0x08], from: 1))
    }

    func testDecode_startIndexPastEnd_returnsNil() {
        XCTAssertNil(VarintCodec.decode([0x08], from: 5))
    }

    func testDecode_negativeStartIndex_returnsNil() {
        XCTAssertNil(VarintCodec.decode([0x01], from: -1))
    }

    /// Field 21, wire type 2: `(21 << 3) | 2` = 170 → varint bytes `0xAA 0x01` (matches `AndroidTVAdapter.parseReceivedData`).
    func testDecode_fieldTag_remoteImeBatchEdit_is170() {
        let r = VarintCodec.decode([0xAA, 0x01])
        XCTAssertEqual(r?.0, 170)
        XCTAssertEqual(r?.1, 2)
    }

    func testDecode_consumesOnlyVarint_notTrailingGarbage() {
        let r = VarintCodec.decode([0x08, 0xFF, 0xFF])
        XCTAssertEqual(r?.0, 8)
        XCTAssertEqual(r?.1, 1)
    }

    func testDecode_threeByteVarint() {
        // 16384 = 0x80 0x80 0x01
        let r = VarintCodec.decode([0x80, 0x80, 0x01])
        XCTAssertEqual(r?.0, 16_384)
        XCTAssertEqual(r?.1, 3)
    }

    /// Fixture: length-delimited field 21 + inner `RemoteImeBatchEdit`-shaped payload (varints only).
    func testFixture_imeBatchEditOuterLength_varintWalk() {
        let inner: [UInt8] = [0x08, 0x05, 0x10, 0x07] // ime_counter=5, field_counter=7
        var outer: [UInt8] = [0xAA, 0x01, 0x04]
        outer.append(contentsOf: inner)
        var index = 2
        guard let (messageLength, lengthBytes) = VarintCodec.decode(outer, from: index) else {
            XCTFail("length varint")
            return
        }
        XCTAssertEqual(messageLength, 4)
        XCTAssertEqual(lengthBytes, 1)
        index += lengthBytes
        XCTAssertEqual(Array(outer[index..<(index + Int(messageLength))]), inner)
    }

    /// Protobuf max encodable unsigned value: 10 bytes (same layout as SwiftProtobuf / conformance tests).
    func testDecode_uint64Max_tenBytes() {
        let bytes: [UInt8] = [
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01
        ]
        let r = VarintCodec.decode(bytes)
        XCTAssertEqual(r?.0, UInt64.max)
        XCTAssertEqual(r?.1, 10)
    }

    func testDecode_dataEmpty_returnsNil() {
        XCTAssertNil(VarintCodec.decode(Data(), from: 0))
    }

    func testDecode_exactlyTenContinuationStepsThenStop_returnsNil() {
        // Ten bytes with continuation set, no terminating byte — hits step limit (mirrors “unterminated varint” cases in decoder fuzz tests).
        let bytes = [UInt8](repeating: 0xFF, count: 10)
        XCTAssertNil(VarintCodec.decode(bytes))
    }

    func testRoundTrip_encodeThenDecode_matchesValues() {
        let samples: [UInt64] = [
            0, 1, 127, 128, 300, 16_383, 16_384, 2_097_151, 2_097_152,
            0x0FFF_FFFF, 0x1_0000_0000, UInt64.max
        ]
        for v in samples {
            let encoded = encodeProtobufVarint(v)
            guard let decoded = VarintCodec.decode(encoded) else {
                XCTFail("decode failed for \(v)")
                continue
            }
            XCTAssertEqual(decoded.0, v, "value \(v)")
            XCTAssertEqual(decoded.1, encoded.count, "length for \(v)")
        }
    }

    func testRoundTrip_decodeFromOffsetInPaddedBuffer() {
        let payload = encodeProtobufVarint(9_999)
        let padded: [UInt8] = [0x01, 0x02, 0x03] + payload + [0xEE]
        guard let decoded = VarintCodec.decode(padded, from: 3) else {
            XCTFail("decode from offset")
            return
        }
        XCTAssertEqual(decoded.0, 9_999)
        XCTAssertEqual(decoded.1, payload.count)
    }
}
