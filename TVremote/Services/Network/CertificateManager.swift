//
//  CertificateManager.swift
//  TVremote
//
//  Self-signed certificate generation and management for TLS connections
//

import Foundation
import Security
import CryptoKit
import Network
import UIKit

/// Manages self-signed certificates for Android TV TLS connections
final class CertificateManager {
    private let keychainTag = "com.tvremote.certificate"
    private let certLabel = "TV Remote Certificate"

    private var cachedIdentity: SecIdentity?
    private var cachedCertificate: SecCertificate?

    static let shared = CertificateManager()

    private init() {}

    /// Get or create the identity (certificate + private key) for TLS connections
    func getIdentity() throws -> SecIdentity {
        if let cached = cachedIdentity {
            return cached
        }

        // Try to load existing identity from keychain
        if let identity = loadIdentityFromKeychain() {
            cachedIdentity = identity
            return identity
        }

        // Create new certificate and identity
        let identity = try createSelfSignedIdentity()
        cachedIdentity = identity
        return identity
    }

    /// Get the certificate for TLS configuration
    func getCertificate() throws -> SecCertificate {
        if let cached = cachedCertificate {
            return cached
        }

        let identity = try getIdentity()
        var cert: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &cert)

        guard status == errSecSuccess, let certificate = cert else {
            throw CertificateError.extractionFailed
        }

        cachedCertificate = certificate
        return certificate
    }

    /// Get the public key data for pairing
    func getPublicKeyData() throws -> Data {
        let certificate = try getCertificate()

        guard let publicKey = SecCertificateCopyKey(certificate) else {
            throw CertificateError.publicKeyExtractionFailed
        }

        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw CertificateError.publicKeyExtractionFailed
        }

        return keyData
    }

    /// Create TLS options for NWConnection
    func createTLSOptions() throws -> NWProtocolTLS.Options {
        let identity = try getIdentity()
        let options = NWProtocolTLS.Options()

        // Set the client certificate identity - this presents the certificate during TLS handshake
        // The TV uses the certificate's public key hash to identify the pairing client
        let secIdentity = sec_identity_create(identity)
        guard secIdentity != nil else {
            throw CertificateError.creationFailed
        }
        
        sec_protocol_options_set_local_identity(
            options.securityProtocolOptions,
            secIdentity!
        )
        
        #if DEBUG
        // Verify certificate is ready and log all details
        let cert = try getCertificate()
        let publicKeyData = try getPublicKeyData()
        let certData = SecCertificateCopyData(cert) as Data
        
        print("[CertificateManager] [DEBUG] ========== CERTIFICATE DETAILS ==========")
        print("[CertificateManager] [DEBUG] Certificate will be presented during TLS handshake")
        print("[CertificateManager] [DEBUG] Certificate data size: \(certData.count) bytes")
        print("[CertificateManager] [DEBUG] Public key size: \(publicKeyData.count) bytes")
        
        // Try to extract CN from certificate
        let certSummary = SecCertificateCopySubjectSummary(cert)
        if let summary = certSummary {
            print("[CertificateManager] [DEBUG] Certificate Subject Summary: \(summary)")
        }
        
        // Verify certificate is not null/empty
        if certData.isEmpty {
            print("[CertificateManager] [DEBUG] ERROR: Certificate data is empty!")
        } else {
            print("[CertificateManager] [DEBUG] Certificate data is valid (non-empty)")
        }
        
        print("[CertificateManager] [DEBUG] ========================================")
        #endif

        // Accept self-signed certificates from Android TV
        sec_protocol_options_set_verify_block(
            options.securityProtocolOptions,
            { _, trust, completionHandler in
                // For local network Android TV, we accept any certificate
                // The pairing process validates the device
                completionHandler(true)
            },
            DispatchQueue.global()
        )

        // Set minimum TLS version
        sec_protocol_options_set_min_tls_protocol_version(
            options.securityProtocolOptions,
            .TLSv12
        )

        return options
    }

    // MARK: - Private Methods

    private func loadIdentityFromKeychain() -> SecIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: certLabel,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            return nil
        }

        return (item as! SecIdentity)
    }

    private func createSelfSignedIdentity() throws -> SecIdentity {
        // Generate RSA key pair
        let keyParams: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: keychainTag.data(using: .utf8)!
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyParams as CFDictionary, &error) else {
            throw CertificateError.keyGenerationFailed
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CertificateError.keyGenerationFailed
        }

        // Create self-signed certificate
        let certificate = try createSelfSignedCertificate(publicKey: publicKey, privateKey: privateKey)

        // Store in keychain
        try storeInKeychain(certificate: certificate, privateKey: privateKey)

        // Retrieve identity
        guard let identity = loadIdentityFromKeychain() else {
            throw CertificateError.storageFailed
        }

        return identity
    }

    private func createSelfSignedCertificate(publicKey: SecKey, privateKey: SecKey) throws -> SecCertificate {
        // Create certificate using Security framework
        // This creates a basic self-signed X.509 certificate

        // Create certificate data manually (DER encoded X.509)
        let certData = try buildSelfSignedCertificateData(publicKey: publicKey, privateKey: privateKey)

        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            throw CertificateError.creationFailed
        }

        return certificate
    }

    private func buildSelfSignedCertificateData(publicKey: SecKey, privateKey: SecKey) throws -> Data {
        // Build a minimal self-signed X.509 certificate
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw CertificateError.publicKeyExtractionFailed
        }

        // Build certificate structure
        var certBuilder = ASN1Builder()

        // TBSCertificate
        var tbsCert = ASN1Builder()

        // Version (v3 = 2)
        tbsCert.addExplicitTag(0, contents: ASN1Builder.integer(2))

        // Serial number
        tbsCert.addInteger(Int.random(in: 1...Int.max))

        // Signature algorithm (SHA256 with RSA)
        tbsCert.addSequence(ASN1Builder.oid([1, 2, 840, 113549, 1, 1, 11]) + ASN1Builder.null())

        // Issuer - Use App Bundle ID as Common Name for uniqueness
        // Sony TVs use Public Key Hash as permanent ID, but CN should be unique
        // Using Bundle ID ensures uniqueness and matches app identity
        let bundleID = Bundle.main.bundleIdentifier ?? "com.tvremote.client"
        let commonName = bundleID
        #if DEBUG
        print("[CertificateManager] [DEBUG] Certificate Common Name (CN): '\(commonName)'")
        print("[CertificateManager] [DEBUG] Using Bundle ID for CN: '\(bundleID)'")
        print("[CertificateManager] [DEBUG] Sony TV uses Public Key Hash as permanent ID, CN must be non-empty and unique")
        #endif
        tbsCert.addSequence(
            ASN1Builder.set(
                ASN1Builder.sequence(
                    ASN1Builder.oid([2, 5, 4, 3]) + ASN1Builder.utf8String(commonName)
                )
            )
        )

        // Validity
        let now = Date()
        let expiry = Calendar.current.date(byAdding: .year, value: 10, to: now)!
        tbsCert.addSequence(
            ASN1Builder.utcTime(now) + ASN1Builder.utcTime(expiry)
        )

        // Subject (same as issuer for self-signed) - must match issuer CN
        #if DEBUG
        print("[CertificateManager] [DEBUG] Certificate Subject CN: '\(commonName)' (matches Issuer)")
        #endif
        tbsCert.addSequence(
            ASN1Builder.set(
                ASN1Builder.sequence(
                    ASN1Builder.oid([2, 5, 4, 3]) + ASN1Builder.utf8String(commonName)
                )
            )
        )

        // Subject public key info
        tbsCert.addSequence(
            ASN1Builder.sequence(
                ASN1Builder.oid([1, 2, 840, 113549, 1, 1, 1]) + ASN1Builder.null()
            ) + ASN1Builder.bitString(publicKeyData)
        )

        let tbsCertData = ASN1Builder.sequence(tbsCert.data)

        // Sign TBSCertificate
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            tbsCertData as CFData,
            &error
        ) as Data? else {
            throw CertificateError.signingFailed
        }

        // Build complete certificate
        certBuilder.addRaw(tbsCertData)
        certBuilder.addSequence(ASN1Builder.oid([1, 2, 840, 113549, 1, 1, 11]) + ASN1Builder.null())
        certBuilder.addBitString(signature)

        return ASN1Builder.sequence(certBuilder.data)
    }

    private func storeInKeychain(certificate: SecCertificate, privateKey: SecKey) throws {
        // Delete existing items
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certLabel
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let deleteKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keychainTag.data(using: .utf8)!
        ]
        SecItemDelete(deleteKeyQuery as CFDictionary)

        // Store certificate
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: certLabel
        ]

        var status = SecItemAdd(certQuery as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw CertificateError.storageFailed
        }

        // Store private key
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecValueRef as String: privateKey,
            kSecAttrApplicationTag as String: keychainTag.data(using: .utf8)!,
            kSecAttrLabel as String: certLabel
        ]

        status = SecItemAdd(keyQuery as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw CertificateError.storageFailed
        }
    }

    /// Clear all stored certificates (for reset/debugging)
    func clearCertificates() {
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certLabel
        ]
        SecItemDelete(certQuery as CFDictionary)

        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keychainTag.data(using: .utf8)!
        ]
        SecItemDelete(keyQuery as CFDictionary)

        cachedIdentity = nil
        cachedCertificate = nil
    }
}

// MARK: - Certificate Errors

enum CertificateError: Error, LocalizedError {
    case keyGenerationFailed
    case creationFailed
    case extractionFailed
    case publicKeyExtractionFailed
    case signingFailed
    case storageFailed

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption keys"
        case .creationFailed:
            return "Failed to create certificate"
        case .extractionFailed:
            return "Failed to extract certificate"
        case .publicKeyExtractionFailed:
            return "Failed to extract public key"
        case .signingFailed:
            return "Failed to sign certificate"
        case .storageFailed:
            return "Failed to store certificate"
        }
    }
}

// MARK: - ASN.1 Builder Helper

/// Simple ASN.1 DER encoding helper for certificate generation
struct ASN1Builder {
    private(set) var data = Data()

    mutating func addRaw(_ rawData: Data) {
        data.append(rawData)
    }

    mutating func addInteger(_ value: Int) {
        data.append(Self.integer(value))
    }

    mutating func addSequence(_ contents: Data) {
        data.append(Self.sequence(contents))
    }

    mutating func addBitString(_ contents: Data) {
        data.append(Self.bitString(contents))
    }

    mutating func addExplicitTag(_ tag: UInt8, contents: Data) {
        var result = Data()
        result.append(0xA0 | tag)
        result.append(contentsOf: Self.encodeLength(contents.count))
        result.append(contents)
        data.append(result)
    }

    static func integer(_ value: Int) -> Data {
        var result = Data()
        result.append(0x02) // INTEGER tag

        var bytes = withUnsafeBytes(of: value.bigEndian) { Array($0) }
        // Remove leading zeros but keep at least one byte
        while bytes.count > 1 && bytes.first == 0 && (bytes[1] & 0x80) == 0 {
            bytes.removeFirst()
        }
        // Add leading zero if high bit is set
        if bytes.first! & 0x80 != 0 {
            bytes.insert(0, at: 0)
        }

        result.append(contentsOf: encodeLength(bytes.count))
        result.append(contentsOf: bytes)
        return result
    }

    static func sequence(_ contents: Data) -> Data {
        var result = Data()
        result.append(0x30) // SEQUENCE tag
        result.append(contentsOf: encodeLength(contents.count))
        result.append(contents)
        return result
    }

    static func set(_ contents: Data) -> Data {
        var result = Data()
        result.append(0x31) // SET tag
        result.append(contentsOf: encodeLength(contents.count))
        result.append(contents)
        return result
    }

    static func bitString(_ contents: Data) -> Data {
        var result = Data()
        result.append(0x03) // BIT STRING tag
        result.append(contentsOf: encodeLength(contents.count + 1))
        result.append(0x00) // unused bits
        result.append(contents)
        return result
    }

    static func octetString(_ contents: Data) -> Data {
        var result = Data()
        result.append(0x04) // OCTET STRING tag
        result.append(contentsOf: encodeLength(contents.count))
        result.append(contents)
        return result
    }

    static func oid(_ components: [Int]) -> Data {
        var result = Data()
        result.append(0x06) // OID tag

        var oidBytes = Data()
        if components.count >= 2 {
            oidBytes.append(UInt8(components[0] * 40 + components[1]))
            for i in 2..<components.count {
                oidBytes.append(contentsOf: encodeOIDComponent(components[i]))
            }
        }

        result.append(contentsOf: encodeLength(oidBytes.count))
        result.append(oidBytes)
        return result
    }

    static func null() -> Data {
        return Data([0x05, 0x00])
    }

    static func utf8String(_ string: String) -> Data {
        var result = Data()
        result.append(0x0C) // UTF8String tag
        let stringData = string.data(using: .utf8) ?? Data()
        result.append(contentsOf: encodeLength(stringData.count))
        result.append(stringData)
        return result
    }

    static func utcTime(_ date: Date) -> Data {
        var result = Data()
        result.append(0x17) // UTCTime tag

        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: date) + "Z"
        let dateData = dateString.data(using: .ascii) ?? Data()

        result.append(contentsOf: encodeLength(dateData.count))
        result.append(dateData)
        return result
    }

    static func encodeLength(_ length: Int) -> [UInt8] {
        if length < 128 {
            return [UInt8(length)]
        } else if length < 256 {
            return [0x81, UInt8(length)]
        } else if length < 65536 {
            return [0x82, UInt8(length >> 8), UInt8(length & 0xFF)]
        } else {
            return [0x83, UInt8(length >> 16), UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)]
        }
    }

    private static func encodeOIDComponent(_ value: Int) -> [UInt8] {
        if value < 128 {
            return [UInt8(value)]
        }

        var bytes: [UInt8] = []
        var v = value
        bytes.append(UInt8(v & 0x7F))
        v >>= 7
        while v > 0 {
            bytes.insert(UInt8(v & 0x7F) | 0x80, at: 0)
            v >>= 7
        }
        return bytes
    }
}
