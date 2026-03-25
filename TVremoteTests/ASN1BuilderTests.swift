//
//  ASN1BuilderTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

final class ASN1BuilderTests: XCTestCase {
    func testEncodeLength_shortForm() {
        XCTAssertEqual(ASN1Builder.encodeLength(0), [0])
        XCTAssertEqual(ASN1Builder.encodeLength(127), [127])
    }

    func testEncodeLength_longForm_oneByte() {
        XCTAssertEqual(ASN1Builder.encodeLength(200), [0x81, 200])
    }

    func testEncodeLength_longForm_twoBytes() {
        XCTAssertEqual(ASN1Builder.encodeLength(0x0100), [0x82, 0x01, 0x00])
    }

    func testNull() {
        XCTAssertEqual(ASN1Builder.null(), Data([0x05, 0x00]))
    }

    func testInteger_zero() {
        let data = ASN1Builder.integer(0)
        XCTAssertEqual(data[0], 0x02)
    }

    func testInteger_positive() {
        let data = ASN1Builder.integer(127)
        XCTAssertEqual(data[0], 0x02)
        XCTAssertTrue(data.count >= 3)
    }

    func testOID_rsaEncryption() {
        let oid = ASN1Builder.oid([1, 2, 840, 113549, 1, 1, 1])
        XCTAssertEqual(oid.first, 0x06)
    }

    func testUTF8String_roundTrip() {
        let encoded = ASN1Builder.utf8String("TVremote")
        XCTAssertEqual(encoded.first, 0x0C)
        XCTAssertTrue(encoded.contains("TVremote".utf8.first!))
    }

    func testSequence_wrapsContents() {
        let inner = Data([0x01, 0x02])
        let seq = ASN1Builder.sequence(inner)
        XCTAssertEqual(seq.first, 0x30)
        XCTAssertTrue(seq.contains(inner))
    }

    func testBuilder_addIntegerAndSequence() {
        var b = ASN1Builder()
        b.addInteger(1)
        XCTAssertFalse(b.data.isEmpty)
        let inner = b.data
        var outer = ASN1Builder()
        outer.addSequence(inner)
        XCTAssertEqual(outer.data.first, 0x30)
    }

    func testBitString_prefixesUnusedBitsByte() {
        let bits = ASN1Builder.bitString(Data([0xAB, 0xCD]))
        XCTAssertEqual(bits.first, 0x03)
        XCTAssertTrue(bits.contains(0x00))
    }
}
