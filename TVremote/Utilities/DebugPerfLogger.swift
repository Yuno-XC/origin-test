//
//  DebugPerfLogger.swift
//  TVremote
//
//  Debug session performance instrumentation
//

import Foundation

#if DEBUG
enum DebugPerfLogger {
    private static let logPath = "/Users/yuno/.cursor/debug-b1092f.log"
    private static let lock = NSLock()

    static func log(location: String, message: String, hypothesisId: String, data: [String: Any] = [:]) {
        lock.lock()
        defer { lock.unlock() }
        var payload: [String: Any] = [
            "sessionId": "b1092f",
            "runId": "pre-fix",
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "data": data
        ]
        if let json = try? JSONSerialization.data(withJSONObject: payload),
           let line = String(data: json, encoding: .utf8) {
            if !FileManager.default.fileExists(atPath: logPath) {
                FileManager.default.createFile(atPath: logPath, contents: nil)
            }
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write((line + "\n").data(using: .utf8)!)
                handle.closeFile()
            }
        }
    }
}
#endif
