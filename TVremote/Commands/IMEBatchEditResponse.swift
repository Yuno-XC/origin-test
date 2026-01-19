//
//  IMEBatchEditResponse.swift
//  TVremote
//
//  Parser for RemoteImeBatchEditResponse from TV
//  Response format: {"remoteImeBatchEdit":{"imeCounter":0,"fieldCounter":0}}
//

import Foundation

/// Parser for RemoteImeBatchEditResponse protobuf message
/// Field 22 (0xB2) in RemoteMessage - RemoteImeBatchEditResponse
struct IMEBatchEditResponse {
    let imeCounter: Int32
    let fieldCounter: Int32
    
    init?(data: Data) {
        // RemoteImeBatchEditResponse structure:
        // Field 1: ime_counter (varint, int32)
        // Field 2: field_counter (varint, int32)
        // Wrapped in RemoteMessage field 22 (0xB2)
        
        var offset = 0
        
        // Check if this is a RemoteMessage with field 22
        // RemoteMessage field 22 = 0xB2 (22 << 3 | 2 = 176 = 0xB0, but let's check for 0xB2)
        // Actually, field 22 wire type 2 = 0xB2 (22 << 3 | 2 = 178 = 0xB2)
        
        guard data.count > 0 else { return nil }
        
        // Look for field 22 (0xB2) marker
        if offset < data.count && data[offset] == 0xB2 {
            offset += 1
            // Read length (varint)
            let (length, lengthBytes) = IMEBatchEditResponse.decodeVarint(data: data, offset: offset)
            offset += lengthBytes
            
            guard offset + Int(length) <= data.count else { return nil }
            let innerData = data.subdata(in: offset..<offset + Int(length))
            offset += Int(length)
            
            // Parse inner RemoteImeBatchEditResponse
            var innerOffset = 0
            var foundImeCounter: Int32?
            var foundFieldCounter: Int32?
            
            while innerOffset < innerData.count {
                guard innerOffset < innerData.count else { break }
                let fieldTag = innerData[innerOffset]
                innerOffset += 1
                
                let fieldNumber = Int32(fieldTag >> 3)
                let wireType = fieldTag & 0x07
                
                if wireType == 0 { // varint
                    let (value, bytesRead) = IMEBatchEditResponse.decodeVarint(data: innerData, offset: innerOffset)
                    innerOffset += bytesRead
                    
                    if fieldNumber == 1 {
                        foundImeCounter = Int32(truncatingIfNeeded: value)
                    } else if fieldNumber == 2 {
                        foundFieldCounter = Int32(truncatingIfNeeded: value)
                    }
                } else {
                    // Skip unknown fields
                    break
                }
            }
            
            if let imeCounter = foundImeCounter, let fieldCounter = foundFieldCounter {
                self.imeCounter = imeCounter
                self.fieldCounter = fieldCounter
                return
            }
        }
        
        // Also try parsing without the outer wrapper (direct response)
        var directOffset = 0
        var foundImeCounter: Int32?
        var foundFieldCounter: Int32?
        
        while directOffset < data.count {
            guard directOffset < data.count else { break }
            let fieldTag = data[directOffset]
            directOffset += 1
            
            let fieldNumber = Int32(fieldTag >> 3)
            let wireType = fieldTag & 0x07
            
            if wireType == 0 { // varint
                let (value, bytesRead) = IMEBatchEditResponse.decodeVarint(data: data, offset: directOffset)
                directOffset += bytesRead
                
                if fieldNumber == 1 {
                    foundImeCounter = Int32(truncatingIfNeeded: value)
                } else if fieldNumber == 2 {
                    foundFieldCounter = Int32(truncatingIfNeeded: value)
                }
            } else {
                // Skip unknown fields
                break
            }
        }
        
        if let imeCounter = foundImeCounter, let fieldCounter = foundFieldCounter {
            self.imeCounter = imeCounter
            self.fieldCounter = fieldCounter
            return
        }
        
        return nil
    }
    
    private static func decodeVarint(data: Data, offset: Int) -> (value: UInt64, bytesRead: Int) {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var bytesRead = 0
        var currentOffset = offset
        
        while currentOffset < data.count {
            let byte = data[currentOffset]
            currentOffset += 1
            bytesRead += 1
            
            result |= UInt64(byte & 0x7F) << shift
            
            if (byte & 0x80) == 0 {
                break
            }
            
            shift += 7
            if shift >= 64 {
                return (0, bytesRead) // Invalid varint
            }
        }
        
        return (result, bytesRead)
    }
}
