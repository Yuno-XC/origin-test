//
//  ProperCodeFile.swift
//  test-remoteide
//
//  Created by Cursor on 30/03/26.
//

import Foundation

enum AppMetadata {
    static let appName = "test-remoteide"

    static var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "unknown"
        return "\(version) (\(build))"
    }
}

enum DebugLog {
    static func info(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[DEBUG] \(message())")
        #endif
    }
}
