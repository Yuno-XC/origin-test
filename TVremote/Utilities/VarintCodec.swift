//
//  VarintCodec.swift
//  TVremote
//
//  Protobuf-style varint decode (shared by Android TV IME parsing and tests)
//

import Foundation

enum VarintCodec {
    /// Decode a varint from `bytes` starting at `startIndex`. Returns `(value, bytesConsumed)` where `bytesConsumed` counts only the varint bytes (from `startIndex`).
    static func decode(_ bytes: [UInt8], from startIndex: Int) -> (UInt64, Int)? {
        decode(startIndex: startIndex, endIndex: bytes.count) { bytes[$0] }
    }

    /// Decode a varint from the full byte array, returns (value, bytesConsumed)
    static func decode(_ bytes: [UInt8]) -> (UInt64, Int)? {
        decode(bytes, from: 0)
    }

    /// Decode a varint from `data` starting at `startIndex`.
    static func decode(_ data: Data, from startIndex: Int) -> (UInt64, Int)? {
        decode(startIndex: startIndex, endIndex: data.count) { data[$0] }
    }

    private static func decode(
        startIndex: Int,
        endIndex: Int,
        byteAt: (Int) -> UInt8
    ) -> (UInt64, Int)? {
        guard startIndex >= 0, startIndex < endIndex else { return nil }

        var result: UInt64 = 0
        var shift: UInt64 = 0
        var index = startIndex
        var steps = 0

        while index < endIndex && steps < 10 {
            let byte = byteAt(index)
            result |= UInt64(byte & 0x7F) << shift

            if byte & 0x80 == 0 {
                return (result, index - startIndex + 1)
            }

            shift += 7
            index += 1
            steps += 1
        }

        return nil
    }
}
