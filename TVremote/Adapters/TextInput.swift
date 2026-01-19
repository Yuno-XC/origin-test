//
//  TextInput.swift
//  TVremote
//
//  Text input implementation using RemoteImeBatchEdit protocol
//  Based on Android TV Remote Protocol v2 remotemessage.proto
//
//  Protocol structure (from https://github.com/tronikos/androidtvremote2):
//
//  message RemoteMessage {
//    RemoteImeBatchEdit remote_ime_batch_edit = 21;
//  }
//
//  message RemoteImeBatchEdit {
//    int32 ime_counter = 1;
//    int32 field_counter = 2;
//    repeated RemoteEditInfo edit_info = 3;
//  }
//
//  message RemoteEditInfo {
//    int32 insert = 1;
//    RemoteImeObject text_field_status = 2;
//  }
//
//  message RemoteImeObject {
//    int32 start = 1;
//    int32 end = 2;
//    string value = 3;
//  }

import Foundation
import AndroidTVRemoteControl

/// Text input message using RemoteImeBatchEdit protocol
public struct TextInput: RequestDataProtocol {
    let text: String
    let imeCounter: Int
    let fieldCounter: Int

    /// Create a text input message
    /// - Parameters:
    ///   - text: The text to send to Android TV
    ///   - imeCounter: IME counter from TV response (default 0)
    ///   - fieldCounter: Field counter from TV response (default 0)
    public init(_ text: String, imeCounter: Int = 0, fieldCounter: Int = 0) {
        self.text = text
        self.imeCounter = imeCounter
        self.fieldCounter = fieldCounter
    }

    public var data: Data {
        // Build from innermost to outermost

        // 1. Build RemoteImeObject
        //    message RemoteImeObject {
        //      int32 start = 1;
        //      int32 end = 2;
        //      string value = 3;
        //    }
        // For text insertion/appending, start and end represent the cursor position.
        // When setting text, both should be set to the length of the text being set.
        // This tells the TV to place the cursor at the end after inserting.
        var imeObject = Data()
        let cursorPosition = text.count
        
        // Field 1: start (int32) = text.count (cursor at end of inserted text)
        imeObject.append(0x08) // Field tag: (1 << 3) | 0 = 8
        imeObject.append(contentsOf: encodeVarint(UInt64(cursorPosition)))

        // Field 2: end (int32) = text.count (same as start for cursor position)
        imeObject.append(0x10) // Field tag: (2 << 3) | 0 = 16
        imeObject.append(contentsOf: encodeVarint(UInt64(cursorPosition)))

        // Field 3: value (string) = text
        imeObject.append(0x1A) // Field tag: (3 << 3) | 2 = 26
        let textData = Data(text.utf8)
        imeObject.append(contentsOf: encodeVarint(UInt64(textData.count)))
        imeObject.append(textData)

        // 2. Build RemoteEditInfo
        //    message RemoteEditInfo {
        //      int32 insert = 1;
        //      RemoteImeObject text_field_status = 2;
        //    }
        var editInfo = Data()

        // Field 1: insert (int32) = 1
        editInfo.append(0x08) // Field tag: (1 << 3) | 0 = 8
        editInfo.append(0x01) // Value: 1

        // Field 2: text_field_status (embedded message)
        editInfo.append(0x12) // Field tag: (2 << 3) | 2 = 18
        editInfo.append(contentsOf: encodeVarint(UInt64(imeObject.count)))
        editInfo.append(imeObject)

        // 3. Build RemoteImeBatchEdit
        //    message RemoteImeBatchEdit {
        //      int32 ime_counter = 1;
        //      int32 field_counter = 2;
        //      repeated RemoteEditInfo edit_info = 3;
        //    }
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
        //    message RemoteMessage {
        //      RemoteImeBatchEdit remote_ime_batch_edit = 21;
        //    }
        var message = Data()

        // Field 21: remote_ime_batch_edit (embedded message)
        // Field tag: (21 << 3) | 2 = 168 + 2 = 170 = 0xAA
        message.append(0xAA) // Field tag high bits
        message.append(0x01) // Field tag low bits (varint continuation for field 21)
        message.append(contentsOf: encodeVarint(UInt64(batchEdit.count)))
        message.append(batchEdit)

        #if DEBUG
        print("[TextInput] Built IME batch edit message for text: '\(text)'")
        print("[TextInput] ime_counter: \(imeCounter), field_counter: \(fieldCounter)")
        print("[TextInput] Message size: \(message.count) bytes")
        print("[TextInput] Message hex: \(message.map { String(format: "%02x", $0) }.joined(separator: " "))")
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
