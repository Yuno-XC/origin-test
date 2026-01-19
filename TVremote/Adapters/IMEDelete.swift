//
//  IMEDelete.swift
//  TVremote
//
//  Delete/backspace implementation using RemoteImeBatchEdit protocol
//  Based on Android TV Remote Protocol v2
//

import Foundation
import AndroidTVRemoteControl

/// Delete message using RemoteImeBatchEdit protocol
/// Deletes characters before the cursor
public struct IMEDelete: RequestDataProtocol {
    let deleteCount: Int
    let imeCounter: Int
    let fieldCounter: Int

    /// Create a delete message
    /// - Parameters:
    ///   - deleteCount: Number of characters to delete (default 1 for backspace)
    ///   - imeCounter: IME counter from TV response (default 0)
    ///   - fieldCounter: Field counter from TV response (default 0)
    public init(deleteCount: Int = 1, imeCounter: Int = 0, fieldCounter: Int = 0) {
        self.deleteCount = deleteCount
        self.imeCounter = imeCounter
        self.fieldCounter = fieldCounter
    }

    public var data: Data {
        // Build RemoteEditInfo directly for delete operation
        // Based on research: RemoteEditInfo structure:
        //    Based on research: RemoteEditInfo has:
        //    - beforeLength (int32) = deleteCount (delete N chars before cursor)
        //    - afterLength (int32) = 0 (no deletion after)
        //    - newText (string) = "" (empty, no insertion)
        var editInfo = Data()

        // Field 1: beforeLength (int32) = deleteCount
        editInfo.append(0x08) // Field tag: (1 << 3) | 0 = 8
        editInfo.append(contentsOf: encodeVarint(UInt64(deleteCount)))

        // Field 2: afterLength (int32) = 0
        editInfo.append(0x10) // Field tag: (2 << 3) | 0 = 16
        editInfo.append(0x00) // Value: 0

        // Field 3: newText (string) = "" (empty for delete)
        editInfo.append(0x1A) // Field tag: (3 << 3) | 2 = 26
        editInfo.append(0x00) // Length: 0 (empty string)

        // 3. Build RemoteImeBatchEdit
        var batchEdit = Data()

        // Field 1: ime_counter (int32)
        batchEdit.append(0x08) // Field tag: (1 << 3) | 0 = 8
        batchEdit.append(contentsOf: encodeVarint(UInt64(imeCounter)))

        // Field 2: field_counter (int32)
        batchEdit.append(0x10) // Field tag: (2 << 3) | 0 = 16
        batchEdit.append(contentsOf: encodeVarint(UInt64(fieldCounter)))

        // Field 3: edit_info (repeated embedded message)
        batchEdit.append(0x1A) // Field tag: (3 << 3) | 2 = 26
        batchEdit.append(contentsOf: encodeVarint(UInt64(editInfo.count)))
        batchEdit.append(editInfo)

        // 4. Build RemoteMessage
        var message = Data()

        // Field 21: remote_ime_batch_edit (embedded message)
        message.append(0xAA) // Field tag: (21 << 3) | 2 = 170
        message.append(0x01) // Field tag continuation
        message.append(contentsOf: encodeVarint(UInt64(batchEdit.count)))
        message.append(batchEdit)

        #if DEBUG
        print("[IMEDelete] Built delete message - deleteCount: \(deleteCount)")
        print("[IMEDelete] ime_counter: \(imeCounter), field_counter: \(fieldCounter)")
        print("[IMEDelete] Message size: \(message.count) bytes")
        #endif

        return message
    }

    /// Encode unsigned integer as protocol buffer varint
    private func encodeVarint(_ value: UInt64) -> [UInt8] {
        var result: [UInt8] = []
        var v = value
        while v > 127 {
            result.append(UInt8(v & 0x7F) | 0x80)
            v >>= 7
        }
        result.append(UInt8(v))
        return result
    }
}
