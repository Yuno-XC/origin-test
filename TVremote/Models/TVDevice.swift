//
//  TVDevice.swift
//  TVremote
//
//  Android TV device model
//

import Foundation

/// Represents a discovered Android TV device on the network
struct TVDevice: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let name: String
    let host: String
    let port: Int
    var isPaired: Bool
    var lastConnected: Date?

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 6466,
        isPaired: Bool = false,
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.isPaired = isPaired
        self.lastConnected = lastConnected
    }

    static func == (lhs: TVDevice, rhs: TVDevice) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(host)
        hasher.combine(port)
    }
}
