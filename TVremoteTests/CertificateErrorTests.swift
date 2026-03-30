//
//  CertificateErrorTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

final class CertificateErrorTests: XCTestCase {
    func testCertificateError_descriptions() {
        XCTAssertEqual(CertificateError.keyGenerationFailed.errorDescription, "Failed to generate encryption keys")
        XCTAssertEqual(CertificateError.creationFailed.errorDescription, "Failed to create certificate")
        XCTAssertEqual(CertificateError.extractionFailed.errorDescription, "Failed to extract certificate")
        XCTAssertEqual(CertificateError.publicKeyExtractionFailed.errorDescription, "Failed to extract public key")
        XCTAssertEqual(CertificateError.signingFailed.errorDescription, "Failed to sign certificate")
        XCTAssertEqual(CertificateError.storageFailed.errorDescription, "Failed to store certificate")
    }
}
