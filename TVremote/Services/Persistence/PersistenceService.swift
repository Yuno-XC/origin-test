//
//  PersistenceService.swift
//  TVremote
//
//  Local persistence for saved TVs and preferences
//

import Foundation

/// Handles local persistence of TV devices and user preferences
final class PersistenceService: PersistenceProtocol {
    // MARK: - Keys

    private enum Keys {
        static let savedDevices = "savedDevices"
        static let lastConnectedDeviceId = "lastConnectedDeviceId"
        static let userPreferences = "userPreferences"
        static let recentTexts = "recentTexts"
        static let certificatePrefix = "certificate_"
    }

    // MARK: - Properties

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Keychain access
    private let keychainService = "com.tvremote.certificates"

    // MARK: - Singleton

    static let shared = PersistenceService()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Device Persistence

    func saveDevice(_ device: TVDevice) {
        var devices = loadDevices()

        // Update or add device
        if let index = devices.firstIndex(where: { $0.host == device.host && $0.port == device.port }) {
            devices[index] = device
        } else {
            devices.append(device)
        }

        saveDevices(devices)
    }

    func loadDevices() -> [TVDevice] {
        guard let data = defaults.data(forKey: Keys.savedDevices) else {
            return []
        }

        do {
            return try decoder.decode([TVDevice].self, from: data)
        } catch {
            print("Failed to decode devices: \(error)")
            return []
        }
    }

    func removeDevice(_ device: TVDevice) {
        var devices = loadDevices()
        devices.removeAll { $0.id == device.id }
        saveDevices(devices)

        // Also remove certificate
        removeCertificate(for: device)

        // Clear last connected if it was this device
        if getLastConnectedDevice()?.id == device.id {
            defaults.removeObject(forKey: Keys.lastConnectedDeviceId)
        }
    }

    private func saveDevices(_ devices: [TVDevice]) {
        do {
            let data = try encoder.encode(devices)
            defaults.set(data, forKey: Keys.savedDevices)
        } catch {
            print("Failed to encode devices: \(error)")
        }
    }

    // MARK: - Last Connected Device

    func setLastConnectedDevice(_ device: TVDevice) {
        defaults.set(device.id.uuidString, forKey: Keys.lastConnectedDeviceId)

        // Update last connected timestamp
        var updatedDevice = device
        updatedDevice.lastConnected = Date()
        saveDevice(updatedDevice)
    }

    func getLastConnectedDevice() -> TVDevice? {
        guard let idString = defaults.string(forKey: Keys.lastConnectedDeviceId),
              let id = UUID(uuidString: idString) else {
            return nil
        }

        return loadDevices().first { $0.id == id }
    }

    // MARK: - Certificate Storage

    func saveCertificate(_ data: Data, for device: TVDevice) {
        let key = Keys.certificatePrefix + device.id.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        SecItemAdd(query as CFDictionary, nil)
    }

    func loadCertificate(for device: TVDevice) -> Data? {
        let key = Keys.certificatePrefix + device.id.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    private func removeCertificate(for device: TVDevice) {
        let key = Keys.certificatePrefix + device.id.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - User Preferences

    func savePreference<T: Codable>(_ value: T, forKey key: String) {
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            print("Failed to save preference: \(error)")
        }
    }

    func loadPreference<T: Codable>(forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Recent Text History

    func loadRecentTexts() -> [String] {
        loadPreference(forKey: Keys.recentTexts) ?? []
    }

    @discardableResult
    func rememberRecentText(_ text: String, limit: Int = 8) -> [String] {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            return loadRecentTexts()
        }

        var recentTexts = loadRecentTexts()
        recentTexts.removeAll { $0 == normalizedText }
        recentTexts.insert(normalizedText, at: 0)

        if recentTexts.count > limit {
            recentTexts = Array(recentTexts.prefix(limit))
        }

        savePreference(recentTexts, forKey: Keys.recentTexts)
        return recentTexts
    }

    func clearRecentTexts() {
        defaults.removeObject(forKey: Keys.recentTexts)
    }

    // MARK: - Clear All Data

    func clearAllData() {
        // Clear UserDefaults
        defaults.removeObject(forKey: Keys.savedDevices)
        defaults.removeObject(forKey: Keys.lastConnectedDeviceId)
        defaults.removeObject(forKey: Keys.userPreferences)
        defaults.removeObject(forKey: Keys.recentTexts)

        // Clear all certificates from keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]
        SecItemDelete(query as CFDictionary)

        // Clear app certificate
        CertificateManager.shared.clearCertificates()
    }
}
