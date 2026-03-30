//
//  SonyBraviaREST.swift
//  TVremote
//
//  Sony Bravia REST API implementation with actRegister pairing
//

import Foundation

/// Sony Bravia REST API client for pairing and remote control
final class SonyBraviaREST {
    private let host: String
    private let port: UInt16
    private let authKey: String
    private let session: URLSession
    private var authCookie: String? // Cookie received after successful PIN submission

    init(host: String, port: UInt16 = 80, authKey: String = "0000", urlSession: URLSession = .shared) {
        self.host = host
        self.port = port
        self.authKey = authKey
        self.session = urlSession
    }
    
    /// Set the authentication cookie (called after successful PIN submission)
    func setAuthCookie(_ cookie: String) {
        self.authCookie = cookie
        #if DEBUG
        print("[SonyBraviaREST] Authentication cookie set: \(cookie.prefix(50))...")
        #endif
    }
    
    /// Clear the authentication cookie
    func clearAuthCookie() {
        self.authCookie = nil
        #if DEBUG
        print("[SonyBraviaREST] Authentication cookie cleared")
        #endif
    }
    
    /// Send a JSON-RPC request to Sony REST API
    private func sendRequest(service: String, method: String, params: [Any] = [], version: String = "1.0") async throws -> [String: Any] {
        let urlString = "http://\(host):\(port)/sony/\(service)"
        guard let url = URL(string: urlString) else {
            throw SonyBraviaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authKey, forHTTPHeaderField: "X-Auth-PSK")
        
        // Add authentication cookie if available (from PIN pairing)
        if let cookie = authCookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
            #if DEBUG
            print("[SonyBraviaREST] Using authentication cookie for request")
            #endif
        }
        
        let jsonRPC: [String: Any] = [
            "method": method,
            "id": Int.random(in: 1...10000),
            "params": params,
            "version": version
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonRPC)
        
        #if DEBUG
        print("[SonyBraviaREST] Sending request to \(urlString)")
        print("[SonyBraviaREST] Method: \(method), Params: \(params)")
        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            print("[SonyBraviaREST] Request body: \(bodyString)")
        }
        #endif
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SonyBraviaError.invalidResponse
        }
        
        #if DEBUG
        print("[SonyBraviaREST] Response status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[SonyBraviaREST] Response body: \(responseString)")
        }
        #endif
        
        guard httpResponse.statusCode == 200 else {
            throw SonyBraviaError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SonyBraviaError.invalidResponse
        }
        
        // Check for error in response
        if let error = json["error"] as? [Any], !error.isEmpty {
            let errorCode = error[0] as? Int ?? -1
            let errorMessage = error.count > 1 ? (error[1] as? String ?? "Unknown error") : "Unknown error"
            throw SonyBraviaError.restAPIError(code: errorCode, message: errorMessage)
        }
        
        return json
    }
    
    /// Register device for pairing (actRegister) - triggers 6-digit code on TV
    func actRegister(clientId: String, nickname: String) async throws -> Bool {
        // Try multiple payload variations and authentication combinations
        // Some 2018 Sony Bravia TVs are picky about payload format
        
        // Payload variations to try:
        // 1. Full payload with level:private and WOL
        // 2. Full payload with level:private, no WOL (empty array)
        // 3. Minimal payload without level field, with WOL
        // 4. Minimal payload without level field, no WOL (empty array)
        // 5. Simple nickname variations
        
        let payloadVariations: [(includeLevel: Bool, useWOL: Bool, nickname: String)] = [
            (true, true, nickname),           // Full with level and WOL
            (true, false, nickname),          // Full with level, no WOL
            (false, true, nickname),          // Minimal without level, with WOL
            (false, false, nickname),         // Minimal without level, no WOL
            (false, false, "Test iOS Remote"), // Minimal with simpler nickname
            (false, false, "iOS Remote"),     // Even simpler nickname
        ]
        
        // Authentication combinations:
        // 1. No PSK (for PIN mode)
        // 2. With PSK (for PSK-only mode)
        let authCombinations: [Bool] = [false, true]
        
        var lastError: Error?
        var triedWithoutPSK = false
        var triedWithPSK = false
        
        // First, try without PSK (PIN mode) with all payload variations
        for usePSK in authCombinations {
            if usePSK {
                triedWithPSK = true
            } else {
                triedWithoutPSK = true
            }
            
            for (includeLevel, useWOL, tryNickname) in payloadVariations {
                do {
                    if let result = try await actRegisterWithVariation(
                        clientId: clientId,
                        nickname: tryNickname,
                        usePSK: usePSK,
                        includeLevel: includeLevel,
                        useWOL: useWOL
                    ) {
                        return result
                    }
                } catch {
                    lastError = error
                    #if DEBUG
                    print("[SonyBraviaREST] Attempt failed (PSK: \(usePSK), Level: \(includeLevel), WOL: \(useWOL), Nickname: \(tryNickname)): \(error)")
                    #endif
                    // Continue to next variation
                }
            }
        }
        
        // If all combinations failed, throw the last error or a helpful message
        if let error = lastError {
            throw error
        }
        
        // Provide comprehensive error message
        var errorMessage = "Authentication failed (401) after trying all payload and authentication combinations. Please check your TV settings:\n"
        errorMessage += "1. Settings → Network → IP Control → Remote Device Settings → Control Remotely (must be ON)\n"
        errorMessage += "2. Settings → Network → IP Control → Authentication → Set to 'Normal' or 'Normal and Pre-Shared Key'\n"
        errorMessage += "3. Settings → Network → IP Control → Deregister all remote devices, then restart TV\n"
        if triedWithPSK {
            errorMessage += "4. If PSK is set on TV, ensure it matches the PSK in the app (currently: '\(authKey)')\n"
        }
        if triedWithoutPSK {
            errorMessage += "5. If PSK is not set on TV, ensure Authentication is set to 'Normal' (not 'Pre-Shared Key' only)"
        }
        
        throw SonyBraviaError.restAPIError(code: 401, message: errorMessage)
    }
    
    private func actRegisterWithVariation(clientId: String, nickname: String, usePSK: Bool, includeLevel: Bool, useWOL: Bool) async throws -> Bool? {
        // Build payload based on variation parameters
        let urlString = "http://\(host):\(port)/sony/accessControl"
        guard let url = URL(string: urlString) else {
            throw SonyBraviaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add PSK header if needed (for PSK-only mode)
        if usePSK {
            request.setValue(authKey, forHTTPHeaderField: "X-Auth-PSK")
            #if DEBUG
            print("[SonyBraviaREST] Using PSK: \(authKey)")
            #endif
        }
        
        // Build client info dict - try with or without level field
        var clientInfo: [String: Any] = [
            "clientid": clientId,
            "nickname": nickname
        ]
        if includeLevel {
            clientInfo["level"] = "private"
        }
        
        // Build params array: [clientInfoDict, WOLArray]
        var params: [Any] = [clientInfo]
        
        // Add WOL parameter if requested
        if useWOL {
            // WOL as array containing dict
            params.append([
                ["function": "WOL", "value": "yes"]
            ])
        } else {
            // Empty array for second param
            params.append([])
        }
        
        let payload: [String: Any] = [
            "method": "actRegister",
            "version": "1.0",
            "id": Int.random(in: 1...10000),
            "params": params
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        #if DEBUG
        print("[SonyBraviaREST] Sending actRegister to \(urlString) (PSK: \(usePSK ? "yes" : "no"), Level: \(includeLevel), WOL: \(useWOL ? "yes" : "no"), Nickname: \(nickname))")
        print("[SonyBraviaREST] Client ID: \(clientId)")
        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            print("[SonyBraviaREST] Request body: \(bodyString)")
        }
        #endif
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SonyBraviaError.invalidResponse
        }
        
        #if DEBUG
        print("[SonyBraviaREST] Response status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[SonyBraviaREST] Response body: \(responseString)")
        }
        #endif
        
        // Parse JSON to check for JSON-RPC errors even on 401
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // If 401 and we didn't use PSK, return nil to try with PSK
        if httpResponse.statusCode == 401 && !usePSK {
            #if DEBUG
            print("[SonyBraviaREST] Got 401 without PSK, will try other variations")
            #endif
            return nil
        }
        
        // If 401 with PSK, provide helpful error message
        if httpResponse.statusCode == 401 && usePSK {
            if let json = json, let error = json["error"] as? [Any], !error.isEmpty {
                let errorCode = error[0] as? Int ?? -1
                let errorMessage = error.count > 1 ? (error[1] as? String ?? "Unknown error") : "Unknown error"
                // Check if error message suggests PSK is not required
                let errorMsgLower = errorMessage.lowercased()
                if errorMsgLower.contains("psk") || errorMsgLower.contains("pre-shared") {
                    throw SonyBraviaError.restAPIError(code: errorCode, message: "Authentication failed (401). The PSK '\(authKey)' may be incorrect. Please check your TV settings:\n1. Settings → Network → IP Control → Pre-Shared Key\n2. If PSK is not set on TV, the app should work without PSK (already tried)\n3. If PSK is set on TV, ensure it matches '\(authKey)' or configure the app with the correct PSK")
                } else {
                    throw SonyBraviaError.restAPIError(code: errorCode, message: "Authentication failed (401). Please check your TV settings:\n1. Settings → Network → IP Control → Remote Device Settings → Control Remotely (must be ON)\n2. Settings → Network → IP Control → Authentication → Set to 'Normal' or 'Normal and Pre-Shared Key'\n3. If using PSK, ensure it matches the PSK in the app (currently: '\(authKey)')")
                }
            }
            return nil // Try next variation
        }
        
        guard httpResponse.statusCode == 200 else {
            return nil // Try next variation
        }
        
        // Parse JSON response to check for JSON-RPC errors
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SonyBraviaError.invalidResponse
        }
        
        // Check for JSON-RPC error (even if HTTP status is 200)
        if let error = json["error"] as? [Any], !error.isEmpty {
            let errorCode = error[0] as? Int ?? -1
            let errorMessage = error.count > 1 ? (error[1] as? String ?? "Unknown error") : "Unknown error"
            
            #if DEBUG
            print("[SonyBraviaREST] JSON-RPC error: \(errorCode) - \(errorMessage)")
            #endif
            
            // Handle specific error cases
            if errorCode == 40005 && errorMessage.contains("Display Is Turned off") {
                throw SonyBraviaError.restAPIError(code: errorCode, message: "TV display is off. Please turn on the TV and try again.")
            }
            
            // If PSK-only mode succeeded (200 with result), return success
            if usePSK, let result = json["result"] as? [Any], !result.isEmpty {
                #if DEBUG
                print("[SonyBraviaREST] PSK-only mode successful - device registered without PIN")
                #endif
                return true
            }
            
            return nil // Try next variation
        }
        
        // Success - TV should show 6-digit code (or already registered if PSK mode)
        #if DEBUG
        if usePSK {
            print("[SonyBraviaREST] actRegister successful with PSK - device registered without PIN")
        } else {
            print("[SonyBraviaREST] actRegister successful - 6-digit code should appear on TV")
        }
        #endif
        return true
    }
    
    // Legacy method kept for compatibility - delegates to new variation method
    private func actRegisterWithPSK(clientId: String, nickname: String, usePSK: Bool, useWOL: Bool = true) async throws -> Bool? {
        return try await actRegisterWithVariation(
            clientId: clientId,
            nickname: nickname,
            usePSK: usePSK,
            includeLevel: true,
            useWOL: useWOL
        )
    }
    
    /// Submit PIN code with Basic Auth to complete pairing
    func submitPIN(clientId: String, nickname: String, pin: String) async throws -> Bool {
        let urlString = "http://\(host):\(port)/sony/accessControl"
        guard let url = URL(string: urlString) else {
            throw SonyBraviaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Same payload as actRegister - try multiple variations if first fails
        // Start with minimal payload (no level field, empty WOL array) as it's most compatible
        let payloadVariations: [[String: Any]] = [
            // Minimal payload (most compatible)
            [
                "method": "actRegister",
                "version": "1.0",
                "id": Int.random(in: 1...10000),
                "params": [
                    [
                        "clientid": clientId,
                        "nickname": nickname
                    ],
                    []
                ]
            ],
            // With level field
            [
                "method": "actRegister",
                "version": "1.0",
                "id": Int.random(in: 1...10000),
                "params": [
                    [
                        "clientid": clientId,
                        "nickname": nickname,
                        "level": "private"
                    ],
                    []
                ]
            ],
            // With WOL
            [
                "method": "actRegister",
                "version": "1.0",
                "id": Int.random(in: 1...10000),
                "params": [
                    [
                        "clientid": clientId,
                        "nickname": nickname
                    ],
                    [
                        ["function": "WOL", "value": "yes"]
                    ]
                ]
            ],
            // Full payload
            [
                "method": "actRegister",
                "version": "1.0",
                "id": Int.random(in: 1...10000),
                "params": [
                    [
                        "clientid": clientId,
                        "nickname": nickname,
                        "level": "private"
                    ],
                    [
                        ["function": "WOL", "value": "yes"]
                    ]
                ]
            ]
        ]
        
        var lastError: Error?
        
        for (index, payload) in payloadVariations.enumerated() {
            var tryRequest = URLRequest(url: url)
            tryRequest.httpMethod = "POST"
            tryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            tryRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            // Add Basic Auth with PIN (empty username, PIN as password)
            let authString = ":\(pin)"
            guard let authData = authString.data(using: .utf8) else {
                throw SonyBraviaError.invalidResponse
            }
            let base64 = authData.base64EncodedString()
            tryRequest.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            
            #if DEBUG
            print("[SonyBraviaREST] Submitting PIN (variation \(index + 1)/\(payloadVariations.count)): \(pin)")
            #endif
            
            do {
                let (data, response) = try await session.data(for: tryRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SonyBraviaError.invalidResponse
                }
                
                #if DEBUG
                print("[SonyBraviaREST] PIN submission status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[SonyBraviaREST] Response body: \(responseString)")
                }
                #endif
                
                guard httpResponse.statusCode == 200 else {
                    if index < payloadVariations.count - 1 {
                        #if DEBUG
                        print("[SonyBraviaREST] PIN submission failed with variation \(index + 1), trying next...")
                        #endif
                        lastError = SonyBraviaError.httpError(httpResponse.statusCode)
                        continue
                    } else {
                        throw SonyBraviaError.httpError(httpResponse.statusCode)
                    }
                }
                
                // Extract authentication cookie from response headers
                if let setCookieHeader = httpResponse.value(forHTTPHeaderField: "Set-Cookie") {
                    let cookieParts = setCookieHeader.components(separatedBy: ";")
                    if let cookieValue = cookieParts.first?.trimmingCharacters(in: .whitespaces) {
                        self.authCookie = cookieValue
                        #if DEBUG
                        print("[SonyBraviaREST] Authentication cookie extracted: \(cookieValue.prefix(50))...")
                        #endif
                    }
                } else {
                    // Try to extract from URLSession's cookie storage
                    if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
                        for cookie in cookies {
                            if cookie.name.lowercased().contains("auth") || 
                               cookie.name.lowercased().contains("session") ||
                               cookie.name.lowercased().contains("access") {
                                let cookieString = "\(cookie.name)=\(cookie.value)"
                                self.authCookie = cookieString
                                #if DEBUG
                                print("[SonyBraviaREST] Authentication cookie extracted from cookie storage: \(cookieString.prefix(50))...")
                                #endif
                                break
                            }
                        }
                    }
                }
                
                // Parse JSON response to check for JSON-RPC errors
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw SonyBraviaError.invalidResponse
                }
                
                // Check for JSON-RPC error
                if let error = json["error"] as? [Any], !error.isEmpty {
                    let errorCode = error[0] as? Int ?? -1
                    let errorMessage = error.count > 1 ? (error[1] as? String ?? "Unknown error") : "Unknown error"
                    
                    if index < payloadVariations.count - 1 {
                        #if DEBUG
                        print("[SonyBraviaREST] JSON-RPC error with variation \(index + 1), trying next...")
                        #endif
                        lastError = SonyBraviaError.restAPIError(code: errorCode, message: errorMessage)
                        continue
                    } else {
                        throw SonyBraviaError.restAPIError(code: errorCode, message: errorMessage)
                    }
                }
                
                #if DEBUG
                if authCookie != nil {
                    print("[SonyBraviaREST] PIN submission successful - cookie stored for future requests")
                } else {
                    print("[SonyBraviaREST] PIN submission successful - no cookie found in response (may use PSK only)")
                }
                #endif
                
                return true
            } catch {
                if index < payloadVariations.count - 1 {
                    lastError = error
                    continue
                } else {
                    throw error
                }
            }
        }
        
        // If all variations failed, throw the last error
        if let error = lastError {
            throw error
        }
        
        throw SonyBraviaError.invalidResponse
    }
    
    /// Get remote device settings
    func getRemoteDeviceSettings() async throws -> [[String: Any]] {
        let response = try await sendRequest(service: "system", method: "getRemoteDeviceSettings", version: "1.0")
        return response["result"] as? [[String: Any]] ?? []
    }
    
    /// Get remote controller info (IRCC codes)
    func getRemoteControllerInfo() async throws -> [[String: Any]] {
        let response = try await sendRequest(service: "system", method: "getRemoteControllerInfo", version: "1.0")
        return response["result"] as? [[String: Any]] ?? []
    }
    
    /// Send remote control command via REST API
    func sendRemoteControlCommand(command: String) async throws {
        let params: [Any] = [
            [
                "IRCCCode": command
            ]
        ]
        
        try await sendRequest(service: "IRCC", method: "setIRCCCode", params: params)
    }
    
    /// Get the current authentication cookie (for debugging or persistence)
    func getAuthCookie() -> String? {
        return authCookie
    }
}

