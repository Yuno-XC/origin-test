//
//  PerformanceTests.swift
//  TVremoteTests
//
//  Focused performance baselines for core hot paths.
//

import XCTest
@testable import TVremote

final class PerformanceTests: XCTestCase {
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

    func testVarintDecode_performance() {
        let samples: [UInt64] = [
            0, 1, 127, 128, 300, 16_383, 16_384, 2_097_151, 2_097_152,
            0x0FFF_FFFF, 0x1_0000_0000, UInt64.max
        ]
        let buffers = samples.map(encodeProtobufVarint)

        var checksum: UInt64 = 0

        measure(metrics: [XCTClockMetric()]) {
            checksum = 0
            for _ in 0..<2_500 {
                for buffer in buffers {
                    guard let decoded = VarintCodec.decode(buffer) else {
                        XCTFail("decode returned nil")
                        return
                    }
                    checksum &+= decoded.0
                }
            }
        }

        XCTAssertGreaterThan(checksum, 0)
    }
}
