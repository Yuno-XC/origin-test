//
//  IMEBatchEdit.swift
//  TVremote
//
//  IME (Input Method Editor) batch edit for text input
//  Based on Android TV Remote Protocol v2 RemoteImeBatchEdit message
//

import Foundation
import AndroidTVRemoteControl

/// IME batch edit message for sending text input to Android TV
/// Based on Stack Overflow answer: https://stackoverflow.com/questions/78075217
/// Structure:
///   remoteImeBatchEdit: {
///     imeCounter,
///     fieldCounter,
///     editInfo: [{
///       insert: 0,
///       textFieldStatus: {
///         start: text.length - 1,
///         end: text.length - 1,
///         value: text
///       }
///     }]
///   }
struct IMEBatchEdit: RequestDataProtocol {
    let text: String
    let imeCounter: Int32
    let fieldCounter: Int32
    
    init(text: String, imeCounter: Int32, fieldCounter: Int32) {
        self.text = text
        self.imeCounter = imeCounter
        self.fieldCounter = fieldCounter
    }
    
    var data: Data {
        // RemoteImeBatchEdit message structure (field 21 in RemoteMessage):
        // Field 1: ime_counter (varint, int32)
        // Field 2: field_counter (varint, int32)
        // Field 3: edit_info (repeated, length-delimited, RemoteEditInfo)
        //   RemoteEditInfo:
        //     Field 1: insert (varint, int32) - position, 0 for append
        //     Field 2: text_field_status (length-delimited, RemoteImeObject)
        //       RemoteImeObject:
        //         Field 1: start (varint, int32)
        //         Field 2: end (varint, int32)
        //         Field 3: value (string)
        
        var innerData = Data()
        
        // Field 1: ime_counter (varint)
        let imeCounterBytes = encodeVarint(UInt64(imeCounter))
        innerData.append(contentsOf: [0x08]) // field 1, wire type 0
        innerData.append(contentsOf: imeCounterBytes)
        
        // Field 2: field_counter (varint)
        let fieldCounterBytes = encodeVarint(UInt64(fieldCounter))
        innerData.append(contentsOf: [0x10]) // field 2, wire type 0
        innerData.append(contentsOf: fieldCounterBytes)
        
        // Field 3: edit_info (repeated, but we send one)
        let textBytes = text.utf8
        let textLength = textBytes.count
        
        // RemoteEditInfo:
        // Field 1: insert = 0 (varint)
        let insertBytes: [UInt8] = [0x08, 0x00] // field 1, wire type 0, value 0
        
        // Field 2: text_field_status (RemoteImeObject)
        //   start = text.length - 1
        //   end = text.length - 1
        //   value = text
        let startValue = max(0, textLength - 1)
        let startBytes = encodeVarint(UInt64(startValue))
        let endBytes = encodeVarint(UInt64(startValue))
        let valueLengthBytes = encodeVarint(UInt64(textLength))
        
        // Build RemoteImeObject (text_field_status)
        var textFieldStatusData = Data()
        textFieldStatusData.append(0x12) // field 2, wire type 2 (length-delimited)
        
        // Calculate length: start field + end field + value field
        let statusLength = 1 + startBytes.count + 1 + endBytes.count + 1 + valueLengthBytes.count + textLength
        textFieldStatusData.append(contentsOf: encodeVarint(UInt64(statusLength)))
        textFieldStatusData.append(0x08) // start field, wire type 0
        textFieldStatusData.append(contentsOf: startBytes)
        textFieldStatusData.append(0x10) // end field, wire type 0
        textFieldStatusData.append(contentsOf: endBytes)
        textFieldStatusData.append(0x1A) // value field, wire type 2
        textFieldStatusData.append(contentsOf: valueLengthBytes)
        textFieldStatusData.append(contentsOf: textBytes)
        
        let textFieldStatus = Array(textFieldStatusData)
        
        let editInfoLength = insertBytes.count + textFieldStatus.count
        let editInfoLengthBytes = encodeVarint(UInt64(editInfoLength))
        
        innerData.append(contentsOf: [0x1A]) // field 3, wire type 2 (length-delimited)
        innerData.append(contentsOf: editInfoLengthBytes)
        innerData.append(contentsOf: insertBytes)
        innerData.append(contentsOf: textFieldStatus)
        
        // Wrap in RemoteMessage: field 21 (0xAA), length, then inner data
        let lengthBytes = encodeVarint(UInt64(innerData.count))
        var outerData = Data([0xAA]) // field 21, wire type 2
        outerData.append(contentsOf: lengthBytes)
        outerData.append(contentsOf: innerData)
        
        #if DEBUG
        print("[IMEBatchEdit] 📝 Created IME message:")
        print("[IMEBatchEdit]   text: '\(text)'")
        print("[IMEBatchEdit]   imeCounter: \(imeCounter)")
        print("[IMEBatchEdit]   fieldCounter: \(fieldCounter)")
        print("[IMEBatchEdit]   start/end: \(startValue)")
        print("[IMEBatchEdit]   Message hex: \(Array(outerData).map { String(format: "%02X", $0) }.joined(separator: " "))")
        #endif
        
        return outerData
    }
    
    private func encodeVarint(_ value: UInt64) -> [UInt8] {
        guard value > 127 else {
            return [UInt8(value)]
        }
        
        var encodedBytes: [UInt8] = []
        var val = value

        while val != 0 {
            var byte = UInt8(val & 0x7F)
            val >>= 7
            if val != 0 {
                byte |= 0x80
            }
            encodedBytes.append(byte)
        }

        return encodedBytes
    }
}
