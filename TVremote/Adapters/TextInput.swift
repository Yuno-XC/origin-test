//
//  TextInput.swift
//  TVremote
//
//  Text input implementation for Android TV Remote Protocol
//  Based on documentation from @starscodermoh
//

import Foundation
import AndroidTVRemoteControl

/// Text input message for Android TV Remote Protocol
/// Implements the IME (Input Method Editor) batch edit protocol
public struct TextInput: RequestDataProtocol {
    let text: String
    
    public init(_ text: String) {
        self.text = text
    }
    
    public var data: Data {
        // Convert text to ASCII values
        let asciiValues = text.utf8.map { UInt8($0) }
        let asciiLen = asciiValues.count
        
        #if DEBUG
        print("[TextInput] Building payload for text: '\(text)' (ASCII: \(asciiValues), len: \(asciiLen))")
        #endif
        
        // Build payload following the exact format from documentation:
        // [170, 1, len3, 8, 0, 16, 0, 26, len2, 8, 0, 18, len1, 8, 11, 16, 11, 26, ascii_len, asciiValues...]
        // Where:
        // - 170 = 0xAA = field tag for remoteImeBatchEdit (field 21, wire type 2)
        // - 1 = varint length of the embedded message (will be calculated)
        // - The rest is the RemoteImeBatchEdit message
        
        // Build from innermost to outermost
        // Step 1: Start with ASCII values
        var payload: [UInt8] = asciiValues
        
        // Step 2: Prepend ASCII length
        payload.insert(UInt8(asciiLen), at: 0)
        
        // Step 3: Prepend [8, 11, 16, 11, 26] and calculate len1
        // [8, 11, 16, 11, 26] represents protobuf fields in RemoteImeObject
        // For "A": len1 = 9, block = [8, 11, 16, 11, 26, 1, 65] = 7 bytes
        let header1: [UInt8] = [8, 11, 16, 11, 26]
        let block1Content = header1.count + payload.count // 7 bytes
        let len1 = UInt8(block1Content + 2) // 7 + 2 = 9
        payload.insert(contentsOf: header1, at: 0)
        payload.insert(len1, at: 0)
        
        // Step 4: Prepend [8, 0, 18] and calculate len2
        // [8, 0, 18] represents protobuf fields in RemoteEditInfo
        // For "A": len2 = 13, block = [8, 0, 18, 9, 8, 11, 16, 11, 26, 1, 65] = 11 bytes
        let header2: [UInt8] = [8, 0, 18]
        let block2Content = header2.count + payload.count // 11 bytes
        let len2 = UInt8(block2Content + 2) // 11 + 2 = 13
        payload.insert(contentsOf: header2, at: 0)
        payload.insert(len2, at: 0)
        
        // Step 5: Prepend [8, 0, 16, 0, 26] and calculate len3
        // [8, 0, 16, 0, 26] represents protobuf fields in RemoteImeBatchEdit
        // For "A": len3 = 18, block = [8, 0, 16, 0, 26, 13, 8, 0, 18, 9, 8, 11, 16, 11, 26, 1, 65] = 17 bytes
        let header3: [UInt8] = [8, 0, 16, 0, 26]
        let block3Size = header3.count + payload.count // 17 bytes
        let len3 = UInt8(block3Size + 1) // 17 + 1 = 18
        payload.insert(contentsOf: header3, at: 0)
        payload.insert(len3, at: 0)
        
        // Step 6: Prepend field tag and varint length
        // - 170 (0xAA) = field tag for remoteImeBatchEdit (field 21, wire type 2)
        // - After the field tag, we need the varint-encoded length of the embedded message
        // The length is the size of everything after it (len3 + header3 + rest of payload)
        // But wait - len3 already includes the length of the block after it
        // So the total message length is: len3 (which includes header3 + len2 + len1 + ascii)
        
        // Looking at the user's example: [170, 1, 18, 8, 0, 16, 0, 26, ...]
        // The `1` is suspicious - it should be the varint length, but len3 is 18
        // Maybe `1` is correct and len3 is something else? Or maybe the format wraps it differently?
        
        // Actually, re-reading: maybe `1` is a field number (field 1) in a wrapper?
        // Or maybe the format is: [170, field_tag_1, len3, ...] where field_tag_1 = (1 << 3) | wire_type?
        // Field 1, wire type 2 = (1 << 3) | 2 = 8 | 2 = 10, not 1
        
        // Let me try a different interpretation: maybe the format is NOT standard protobuf
        // and `1` is just a constant. But that doesn't make sense either.
        
        // For now, let's try using the actual varint length (len3 = 18)
        // In protobuf, varint(18) = 18 (single byte since 18 < 128)
        let fieldTag: UInt8 = 170 // 0xAA = field 21, wire type 2
        // The length of the RemoteImeBatchEdit message is len3
        // But varint encoding for 18 is just [18], not [1]
        // So maybe we should use [170, 18, ...] instead of [170, 1, ...]
        // But the user's doc shows [170, 1, ...], so let's try both approaches
        
        // Actually, let me check if maybe `1` is correct and len3 is encoded differently
        // Or maybe the entire structure needs to be wrapped differently
        
        // For now, following the user's exact format: [170, 1, len3, ...]
        // But this might be wrong - the TV is rejecting it
        let fixedHeader: [UInt8] = [170, 1]
        payload.insert(contentsOf: fixedHeader, at: 0)
        
        #if DEBUG
        print("[TextInput] Final payload (without varint length prefix): \(payload)")
        print("[TextInput] Payload length: \(payload.count) bytes")
        print("[TextInput] Payload hex: \(payload.map { String(format: "%02X", $0) }.joined(separator: " "))")
        print("[TextInput] Note: RemoteManager will add varint length prefix automatically")
        print("[TextInput] Expected format: [170, 1, len3, 8, 0, 16, 0, 26, len2, 8, 0, 18, len1, 8, 11, 16, 11, 26, ascii_len, asciiValues...]")
        
        // Verify against example for "A": [170, 1, 18, 8, 0, 16, 0, 26, 13, 8, 0, 18, 9, 8, 11, 16, 11, 26, 1, 65]
        // (without total_len since RemoteManager adds it)
        if text == "A" {
            let expected: [UInt8] = [170, 1, 18, 8, 0, 16, 0, 26, 13, 8, 0, 18, 9, 8, 11, 16, 11, 26, 1, 65]
            if payload == expected {
                print("[TextInput] ✅ Payload matches expected format for 'A'")
            } else {
                print("[TextInput] ⚠️ Payload mismatch for 'A'")
                print("[TextInput] Expected: \(expected)")
                print("[TextInput] Got:      \(payload)")
                print("[TextInput] Differences:")
                for i in 0..<min(expected.count, payload.count) {
                    if expected[i] != payload[i] {
                        print("[TextInput]   Index \(i): expected \(expected[i]), got \(payload[i])")
                    }
                }
            }
        }
        #endif
        
        return Data(payload)
    }
}
