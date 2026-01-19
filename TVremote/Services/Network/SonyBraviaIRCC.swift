//
//  SonyBraviaIRCC.swift
//  TVremote
//
//  Sony Bravia IRCC (Infrared Remote Control Command) over IP implementation
//  Based on: https://github.com/JoshuaRogan/sony-bravia-remote
//

import Foundation

/// Sony Bravia IRCC remote control service
final class SonyBraviaIRCC {
    private let host: String
    private let port: UInt16
    private let authKey: String
    private var authCookie: String? // Cookie from PIN pairing (shared with REST API)
    
    private let session = URLSession.shared
    
    init(host: String, port: UInt16 = 80, authKey: String = "0000") {
        self.host = host
        self.port = port
        self.authKey = authKey
    }
    
    /// Set the authentication cookie (called after successful PIN submission)
    func setAuthCookie(_ cookie: String) {
        self.authCookie = cookie
        #if DEBUG
        print("[SonyBraviaIRCC] Authentication cookie set: \(cookie.prefix(50))...")
        #endif
    }
    
    /// Clear the authentication cookie
    func clearAuthCookie() {
        self.authCookie = nil
        #if DEBUG
        print("[SonyBraviaIRCC] Authentication cookie cleared")
        #endif
    }
    
    /// Send an IRCC command to the TV
    func sendIRCCCommand(_ command: String) async throws {
        // Try both /sony/IRCC and /sony/ircc (some models use lowercase)
        let urlString = "http://\(host):\(port)/sony/IRCC"
        guard let url = URL(string: urlString) else {
            throw SonyBraviaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(authKey, forHTTPHeaderField: "X-Auth-PSK")
        request.setValue("\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\"", forHTTPHeaderField: "SOAPAction")
        
        // Add authentication cookie if available (from PIN pairing)
        if let cookie = authCookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
            #if DEBUG
            print("[SonyBraviaIRCC] Using authentication cookie for IRCC command")
            #endif
        }
        
        // Build SOAP XML body
        let soapBody = """
        <?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <s:Body>
                <u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">
                    <IRCCCode>\(command)</IRCCCode>
                </u:X_SendIRCC>
            </s:Body>
        </s:Envelope>
        """
        
        request.httpBody = soapBody.data(using: .utf8)
        
        #if DEBUG
        print("[SonyBraviaIRCC] Sending IRCC command: \(command) to \(urlString)")
        #endif
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SonyBraviaError.invalidResponse
        }
        
        #if DEBUG
        print("[SonyBraviaIRCC] Response status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[SonyBraviaIRCC] Response body: \(responseString)")
        }
        #endif
        
        guard httpResponse.statusCode == 200 else {
            throw SonyBraviaError.httpError(httpResponse.statusCode)
        }
    }
    
    /// Map Android key codes to Sony IRCC codes
    func getIRCCCode(for keyCode: AndroidKeyCode) -> String? {
        switch keyCode {
        case .home: return "AAAAAQAAAAEAAABgAw=="
        case .back: return "AAAAAgAAAJcAAAAjAw=="
        case .dpadUp: return "AAAAAQAAAAEAAAB0Aw=="
        case .dpadDown: return "AAAAAQAAAAEAAAB1Aw=="
        case .dpadLeft: return "AAAAAQAAAAEAAAB3Aw=="
        case .dpadRight: return "AAAAAQAAAAEAAAB2Aw=="
        case .dpadCenter: return "AAAAAQAAAAEAAABlAw=="
        case .volumeUp: return "AAAAAQAAAAEAAABRAw=="
        case .volumeDown: return "AAAAAQAAAAEAAABSAw=="
        case .mute: return "AAAAAQAAAAEAAAAUAw=="
        case .power: return "AAAAAQAAAAEAAAAVAw=="
        case .mediaPlayPause: return "AAAAAQAAAAEAAABlAw=="
        case .mediaPlay: return "AAAAAQAAAAEAAABkAw=="
        case .mediaPause: return "AAAAAQAAAAEAAABlAw=="
        case .mediaStop: return "AAAAAQAAAAEAAABjAw=="
        case .mediaNext: return "AAAAAQAAAAEAAABgAw=="
        case .mediaPrevious: return "AAAAAQAAAAEAAABhAw=="
        case .menu: return "AAAAAQAAAAEAAAAbAw=="
        default: return nil
        }
    }
}

enum SonyBraviaError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case unsupportedCommand
    case restAPIError(code: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from TV"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .unsupportedCommand:
            return "Unsupported command"
        case .restAPIError(let code, let message):
            return "REST API error \(code): \(message)"
        }
    }
}
