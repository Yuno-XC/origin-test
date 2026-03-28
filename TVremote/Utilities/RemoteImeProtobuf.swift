//
//  RemoteImeProtobuf.swift
//  TVremote
//
//  Parses RemoteImeBatchEdit wrapped as protobuf field 21 (wire type 2, tag varint 0xAA 0x01).
//  Layout matches Android TV Remote protocol buffers (varint / length-delimited walking).
//

import Foundation

enum RemoteImeProtobuf {
    /// Returns IME counters when a well-formed field-21 message is found; `nil` if none or on first parse error after a tag match.
    static func imeCounters(from data: Data) -> (imeCounter: Int, fieldCounter: Int)? {
        guard data.count >= 4 else { return nil }

        var index = data.startIndex
        let end = data.endIndex

        while index < end - 1 {
            if data[index] == 0xAA && data[index + 1] == 0x01 {
                index += 2

                guard let (messageLength, lengthBytes) = VarintCodec.decode(data, from: index) else { return nil }
                index += lengthBytes

                guard index + Int(messageLength) <= end else { return nil }

                let messageEnd = index + Int(messageLength)
                let messageSlice = data.subdata(in: index..<messageEnd)
                return parseImeBatchEdit(messageSlice)
            }
            index += 1
        }

        return nil
    }

    private static func parseImeBatchEdit(_ data: Data) -> (imeCounter: Int, fieldCounter: Int)? {
        var index = 0
        var newImeCounter: Int?
        var newFieldCounter: Int?

        let byteCount = data.count

        while index < byteCount {
            guard let (fieldTag, tagBytes) = VarintCodec.decode(data, from: index) else { break }
            index += tagBytes

            let fieldNumber = fieldTag >> 3
            let wireType = fieldTag & 0x07

            switch (fieldNumber, wireType) {
            case (1, 0):
                guard let (value, valueBytes) = VarintCodec.decode(data, from: index) else { break }
                newImeCounter = Int(value)
                index += valueBytes

            case (2, 0):
                guard let (value, valueBytes) = VarintCodec.decode(data, from: index) else { break }
                newFieldCounter = Int(value)
                index += valueBytes

            case (_, 0):
                guard let (_, valueBytes) = VarintCodec.decode(data, from: index) else { break }
                index += valueBytes

            case (_, 2):
                guard let (length, lengthBytes) = VarintCodec.decode(data, from: index) else { break }
                index += lengthBytes
                guard index + Int(length) <= byteCount else { return nil }
                index += Int(length)

            default:
                return nil
            }
        }

        guard let ime = newImeCounter, let field = newFieldCounter else { return nil }
        return (ime, field)
    }
}
