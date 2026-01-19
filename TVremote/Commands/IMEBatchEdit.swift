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
/// This is more reliable than individual letter keycodes for text input
struct IMEBatchEdit: RequestDataProtocol {
    let text: String
    private var imeCounter: Int64 = 1
    private var fieldCounter: Int64 = 1
    
    init(_ text: String) {
        self.text = text
    }
    
    var data: Data {
        // RemoteImeBatchEdit message structure:
        // Field 3: ime_counter (varint)
        // Field 4: field_counter (varint)  
        // Field 5: ime_object (length-delimited)
        //   - Field 1: text (string)
        // Field 6: edit_info (length-delimited)
        //   - Field 1: start (varint)
        //   - Field 2: end (varint)
        //   - Field 3: new_text (string)
        
        var data = Data()
        
        // Encode ime_counter (field 3, varint)
        let imeCounterBytes = encodeVarint(UInt64(imeCounter))
        data.append(contentsOf: [0x18]) // field 3, wire type 0
        data.append(contentsOf: imeCounterBytes)
        
        // Encode field_counter (field 4, varint)
        let fieldCounterBytes = encodeVarint(UInt64(fieldCounter))
        data.append(contentsOf: [0x20]) // field 4, wire type 0
        data.append(contentsOf: fieldCounterBytes)
        
        // Encode ime_object (field 5, length-delimited)
        let textBytes = text.utf8
        let textLengthBytes = encodeVarint(UInt64(textBytes.count))
        let imeObjectLength = 1 + textLengthBytes.count + textBytes.count // field 1 + length + text
        let imeObjectLengthBytes = encodeVarint(UInt64(imeObjectLength))
        
        data.append(contentsOf: [0x2A]) // field 5, wire type 2 (length-delimited)
        data.append(contentsOf: imeObjectLengthBytes)
        data.append(contentsOf: [0x0A]) // ime_object field 1, wire type 2
        data.append(contentsOf: textLengthBytes)
        data.append(contentsOf: textBytes)
        
        // Encode edit_info (field 6, length-delimited)
        // edit_info contains: start=0, end=0, new_text=text
        let editInfoTextBytes = text.utf8
        let editInfoTextLengthBytes = encodeVarint(UInt64(editInfoTextBytes.count))
        // edit_info fields: start (varint), end (varint), new_text (string)
        let editInfoLength = 1 + 1 + 1 + editInfoTextLengthBytes.count + editInfoTextBytes.count // start + end + new_text field + length + text
        let editInfoLengthBytes = encodeVarint(UInt64(editInfoLength))
        
        data.append(contentsOf: [0x32]) // field 6, wire type 2
        data.append(contentsOf: editInfoLengthBytes)
        data.append(contentsOf: [0x08, 0x00]) // start = 0 (field 1, varint)
        data.append(contentsOf: [0x10, 0x00]) // end = 0 (field 2, varint)
        data.append(contentsOf: [0x1A]) // new_text field 3, wire type 2
        data.append(contentsOf: editInfoTextLengthBytes)
        data.append(contentsOf: editInfoTextBytes)
        
        return data
    }
    
    private func encodeVarint(_ value: UInt64) -> [UInt8] {
        var result: [UInt8] = []
        var val = value
        repeat {
            var byte = UInt8(val & 0x7F)
            val >>= 7
            if val != 0 {
                byte |= 0x80
            }
            result.append(byte)
        } while val != 0
        return result
    }
}
