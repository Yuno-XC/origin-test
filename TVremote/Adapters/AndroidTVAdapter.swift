//
//  AndroidTVAdapter.swift
//  TVremote
//
//  Adapter using AndroidTVRemoteControl package for Android TV protocol
//

import Foundation
import Combine
import AndroidTVRemoteControl
import Security

/// Adapts high-level RemoteActions to Android TV specific commands using AndroidTVRemoteControl package
final class AndroidTVAdapter: TVRemoteAdapterProtocol {
    // MARK: - Properties

    private var pairingManager: PairingManager?
    private var remoteManager: RemoteManager?
    private var cryptoManager: CryptoManager?
    private var tlsManager: TLSManager?
    private var sonyAdapter: SonyBraviaAdapter?
    private var stateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)

    private(set) var currentDevice: TVDevice?
    private var isPairing = false
    private var shouldFallbackToSony = false
    
    // IME counters from TV (needed for text input)
    private var imeCounter: Int32 = 0
    private var fieldCounter: Int32 = 0

    var connectionState: AnyPublisher<ConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var currentState: ConnectionState {
        stateSubject.value
    }

    // MARK: - Initialization

    init() {}

    private func isSonyBravia(_ device: TVDevice) -> Bool {
        let name = device.name.lowercased()
        return name.contains("sony") || 
               name.contains("bravia") ||
               name.contains("ravindra")
    }

    // MARK: - Certificate Management

    private func setupManagers(for device: TVDevice) throws {
        let certificateManager = CertificateManager.shared

        // Setup CryptoManager - provides public key from certificate
        cryptoManager = CryptoManager()
        
        cryptoManager?.clientPublicCertificate = { () -> Result<SecKey> in
            do {
                let identity = try certificateManager.getIdentity()
                var cert: SecCertificate?
                let status = SecIdentityCopyCertificate(identity, &cert)
                
                guard status == errSecSuccess, let certificate = cert else {
                    return .Error(.noClientPublicCertificate)
                }
                
                guard let publicKey = SecCertificateCopyKey(certificate) else {
                    return .Error(.secTrustCopyKeyError)
                }
                
                return .Result(publicKey)
            } catch {
                return .Error(.noClientPublicCertificate)
            }
        }

        // Setup TLSManager - provides certificate items (must return SecIdentity in CFArray)
        tlsManager = TLSManager { () -> Result<CFArray?> in
            do {
                let identity = try certificateManager.getIdentity()
                
                // Create certificate items array with SecIdentity
                // The package expects: [kSecImportItemIdentity: SecIdentity]
                let items: [String: Any] = [
                    kSecImportItemIdentity as String: identity
                ]
                
                return .Result([items] as CFArray)
            } catch {
                return .Error(.secIdentityCreateError)
            }
        }

        // Setup trust handler for TLSManager
        tlsManager?.secTrustClosure = { [weak self] (secTrust: SecTrust) in
            guard let self = self else { return }
            
            #if DEBUG
            print("[AndroidTVAdapter] TLS trust closure called - extracting server certificate")
            #endif
            
            // First, evaluate the trust to get the certificate chain
            var secresult: SecTrustResultType = .invalid
            let status = SecTrustEvaluate(secTrust, &secresult)
            
            guard status == errSecSuccess else {
                #if DEBUG
                print("[AndroidTVAdapter] SecTrustEvaluate failed with status: \(status)")
                #endif
                return
            }
            
            // Get the certificate count
            let certCount = SecTrustGetCertificateCount(secTrust)
            guard certCount > 0 else {
                #if DEBUG
                print("[AndroidTVAdapter] No certificates in trust chain")
                #endif
                return
            }
            
            // Get the first certificate (server's certificate)
            guard let serverCert = SecTrustGetCertificateAtIndex(secTrust, 0) else {
                #if DEBUG
                print("[AndroidTVAdapter] Failed to get server certificate from trust chain")
                #endif
                return
            }
            
            // Extract public key from the certificate
            guard let serverKey = SecCertificateCopyKey(serverCert) else {
                #if DEBUG
                print("[AndroidTVAdapter] Failed to extract public key from server certificate")
                #endif
                return
            }
            
            #if DEBUG
            print("[AndroidTVAdapter] Successfully extracted server public key")
            #endif
            
            // Set the server public certificate in CryptoManager
            self.cryptoManager?.serverPublicCertificate = {
                return .Result(serverKey)
            }
        }

        // Setup PairingManager
        pairingManager = PairingManager(tlsManager!, cryptoManager!, createLogger())

        // Setup RemoteManager with device info
        let deviceInfo = CommandNetwork.DeviceInfo(
            "iPhone",
            "Apple",
            "1.0.0",
            "TVremote",
            "1"
        )
        remoteManager = RemoteManager(tlsManager!, deviceInfo, createLogger())
        
        #if DEBUG
        print("[AndroidTVAdapter] ✅ RemoteManager created and stored")
        print("[AndroidTVAdapter] RemoteManager instance: \(remoteManager != nil ? "exists" : "nil")")
        #endif

        // Setup state change handlers
        setupPairingCallbacks()
        setupRemoteCallbacks()
    }

    private func createLogger() -> Logger {
        #if DEBUG
        return DefaultLogger()
        #else
        return DefaultLogger() // Can create silent logger for release
        #endif
    }

    private func setupPairingCallbacks() {
        pairingManager?.stateChanged = { [weak self] state in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch state {
                case .waitingCode:
                    #if DEBUG
                    print("[AndroidTVAdapter] Pairing: Waiting for 6-digit code on TV")
                    #endif
                    self.stateSubject.send(.pairing(.waitingForCode))
                    
                case .secretSent:
                    #if DEBUG
                    print("[AndroidTVAdapter] Pairing: Secret sent, validating...")
                    #endif
                    self.stateSubject.send(.pairing(.validatingCode))
                    
                case .successPaired:
                    #if DEBUG
                    print("[AndroidTVAdapter] Pairing: Successfully paired!")
                    print("[AndroidTVAdapter] Current device after pairing: \(self.currentDevice?.name ?? "nil")")
                    print("[AndroidTVAdapter] RemoteManager exists after pairing: \(self.remoteManager != nil)")
                    print("[AndroidTVAdapter] CryptoManager exists: \(self.cryptoManager != nil)")
                    print("[AndroidTVAdapter] TLSManager exists: \(self.tlsManager != nil)")
                    #endif
                    self.isPairing = false
                    self.stateSubject.send(.pairing(.success))
                    // After pairing success, connect for remote control
                    // RemoteManager is already set up from setupManagers() in startPairing()
                    Task {
                        try? await self.connectToRemote()
                    }
                    
                case .error(let error):
                    #if DEBUG
                    print("[AndroidTVAdapter] Pairing error: \(error)")
                    #endif
                    self.isPairing = false
                    let errorMessage = self.formatError(error)
                    
                    self.stateSubject.send(.pairing(.failed(errorMessage)))
                    
                default:
                    break
                }
            }
        }
    }

    private func setupRemoteCallbacks() {
        remoteManager?.stateChanged = { [weak self] state in
            guard let self = self else { return }
            
            Task { @MainActor in
                #if DEBUG
                print("[AndroidTVAdapter] 🔄 RemoteManager state changed: \(state)")
                #endif
                
                switch state {
                case .connected:
                    #if DEBUG
                    print("[AndroidTVAdapter] ✅ Remote: Connected and ready")
                    print("[AndroidTVAdapter] ⏳ Waiting for IME batch edit response to get counters from TV...")
                    #endif
                    // Don't reset counters - wait for TV to send them in response
                    // Counters will be updated when we receive remoteImeBatchEditResponse
                    self.stateSubject.send(.connected)
                    
                case .paired(let runningApp):
                    #if DEBUG
                    print("[AndroidTVAdapter] ✅ Remote: Paired, running app: \(runningApp ?? "Unknown")")
                    print("[AndroidTVAdapter] ⏳ Waiting for IME batch edit response to get counters from TV...")
                    #endif
                    // Don't reset counters - wait for TV to send them in response
                    // Counters will be updated when we receive remoteImeBatchEditResponse
                    self.stateSubject.send(.connected)
                    
                case .error(let error):
                    #if DEBUG
                    print("[AndroidTVAdapter] ❌ Remote error: \(error)")
                    #endif
                    self.stateSubject.send(.error(.connectionLost))
                    
                default:
                    #if DEBUG
                    print("[AndroidTVAdapter] ℹ️ Remote state: \(state)")
                    #endif
                    break
                }
            }
        }
        
        // Listen for IME batch edit responses to update counters
        remoteManager?.receiveData = { [weak self] data, error in
            guard let self = self, let data = data, data.count > 0 else { return }
            
            #if DEBUG
            // Log all incoming data to help debug IME response detection
            if data.count < 100 { // Only log small messages to avoid spam
                print("[AndroidTVAdapter] 📥 Received data (\(data.count) bytes): \(Array(data).map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
            #endif
            
            // Parse IME batch edit response if present
            // Response format: RemoteImeBatchEditResponse with imeCounter and fieldCounter
            if let response = IMEBatchEditResponse(data: data) {
                Task { @MainActor in
                    self.imeCounter = response.imeCounter
                    self.fieldCounter = response.fieldCounter
                    #if DEBUG
                    print("[AndroidTVAdapter] ✅ Parsed IME batch edit response:")
                    print("[AndroidTVAdapter]   imeCounter: \(response.imeCounter)")
                    print("[AndroidTVAdapter]   fieldCounter: \(response.fieldCounter)")
                    #endif
                }
            }
        }
    }

    private func formatError(_ error: AndroidTVRemoteControlError) -> String {
        // Format error for user display
        switch error {
        case .invalidCode(let description):
            return "Invalid code: \(description)"
        case .wrongCode:
            return "Wrong code entered"
        case .connectionWaitingError(let error):
            return "Connection error: \(error.localizedDescription)"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .pairingNotSuccess:
            return "Pairing failed"
        default:
            return "Pairing error occurred"
        }
    }

    private func connectToRemote() async throws {
        guard let remoteManager = remoteManager,
              let device = currentDevice else {
            #if DEBUG
            print("[AndroidTVAdapter] ❌ connectToRemote: Missing remoteManager or currentDevice")
            print("[AndroidTVAdapter] remoteManager: \(remoteManager != nil ? "exists" : "nil")")
            print("[AndroidTVAdapter] currentDevice: \(currentDevice?.name ?? "nil")")
            #endif
            throw ConnectionError.deviceUnreachable
        }
        
        #if DEBUG
        print("[AndroidTVAdapter] ✅ connectToRemote: Connecting to \(device.name) at \(device.host)")
        #endif
        
        await MainActor.run {
            stateSubject.send(.connecting)
        }
        
        remoteManager.connect(device.host)
    }

    // MARK: - TVConnectionProtocol

    func connect(to device: TVDevice) async throws {
        #if DEBUG
        print("[AndroidTVAdapter] 🔌 connect() called for device: \(device.name) at \(device.host)")
        print("[AndroidTVAdapter] Setting currentDevice to: \(device.name)")
        #endif
        
        currentDevice = device
        
        #if DEBUG
        print("[AndroidTVAdapter] currentDevice is now: \(currentDevice?.name ?? "nil")")
        print("[AndroidTVAdapter] RemoteManager available: \(remoteManager != nil)")
        print("[AndroidTVAdapter] Is Sony Bravia: \(isSonyBravia(device))")
        #endif
        
        // Priority: If RemoteManager is already set up (from Android TV pairing), use it
        // This takes precedence even for Sony TVs that were paired via Android TV protocol
        if let existingRemoteManager = remoteManager {
            #if DEBUG
            print("[AndroidTVAdapter] ✅ RemoteManager already set up from pairing, reusing it")
            #endif
            
            // Check if already connected
            let currentState = stateSubject.value
            if case .connected = currentState {
                #if DEBUG
                print("[AndroidTVAdapter] Already connected via RemoteManager")
                #endif
                return
            }
            
            // Connect to remote if not already connected
            try await connectToRemote()
            return
        }
        
        // If device is paired but RemoteManager doesn't exist, set it up now
        // This happens when connect() is called after app restart or if managers were cleared
        // IMPORTANT: Even for Sony TVs, if they were paired via Android TV protocol, use RemoteManager
        if device.isPaired {
            #if DEBUG
            print("[AndroidTVAdapter] Device is paired but RemoteManager not set up, initializing...")
            print("[AndroidTVAdapter] This device was paired via Android TV protocol, setting up RemoteManager")
            #endif
            try setupManagers(for: device)
            
            #if DEBUG
            print("[AndroidTVAdapter] RemoteManager after setup: \(remoteManager != nil ? "exists" : "nil")")
            #endif
            
            // Connect to remote
            try await connectToRemote()
            return
        }
        
        // Fallback: For Sony Bravia without pairing, try IRCC
        if isSonyBravia(device) {
            #if DEBUG
            print("[AndroidTVAdapter] No pairing, falling back to IRCC protocol for Sony")
            #endif
            if sonyAdapter == nil {
                sonyAdapter = SonyBraviaAdapter(host: device.host, port: 80, authKey: "0000")
            }
            try await sonyAdapter!.connect(to: device)
            stateSubject.send(.connected)
            return
        }
        
        // For Android TV without pairing, set it up now
        #if DEBUG
        print("[AndroidTVAdapter] Setting up RemoteManager for Android TV (not paired)")
        #endif
        try setupManagers(for: device)
        
        // Only connect if not already connected
        let currentState = stateSubject.value
        if case .connected = currentState {
            #if DEBUG
            print("[AndroidTVAdapter] Already connected, skipping connectToRemote")
            #endif
            return
        }
        
        try await connectToRemote()
    }

    func disconnect() {
        #if DEBUG
        print("[AndroidTVAdapter] 🔌 disconnect() called")
        print("[AndroidTVAdapter] RemoteManager before disconnect: \(remoteManager != nil ? "exists" : "nil")")
        print("[AndroidTVAdapter] Clearing RemoteManager and other managers")
        #endif
        pairingManager = nil
        remoteManager?.disconnect()
        remoteManager = nil
        cryptoManager = nil
        tlsManager = nil
        sonyAdapter?.disconnect()
        sonyAdapter = nil
        currentDevice = nil
        isPairing = false
        stateSubject.send(.disconnected)
        
        #if DEBUG
        print("[AndroidTVAdapter] RemoteManager after disconnect: \(remoteManager != nil ? "exists" : "nil")")
        #endif
    }

    func startPairing(to device: TVDevice) async throws {
        #if DEBUG
        print("[AndroidTVAdapter] Starting pairing to device: \(device.name) at \(device.host)")
        #endif
        
        currentDevice = device
        isPairing = true
        
        // Always try Android TV Remote Protocol first (works for Sony and other TVs)
        // This triggers the 6-digit PIN on port 6467 via TLS
        #if DEBUG
        print("[AndroidTVAdapter] Attempting Android TV Remote Protocol (port 6467) for 6-digit PIN")
        if isSonyBravia(device) {
            print("[AndroidTVAdapter] Note: Sony Bravia detected, but trying Android TV protocol first")
        }
        #endif
        
        // Set flag for fallback if this is a Sony TV
        shouldFallbackToSony = isSonyBravia(device)
        
        do {
            try setupManagers(for: device)
            
            await MainActor.run {
                stateSubject.send(.pairing(.starting))
            }
            
            // Use service name: com.google.android.tv.remote for 6-digit PIN
            // This is the service that triggers the 6-digit PIN on Android TV devices
            pairingManager?.connect(device.host, "client", "com.google.android.tv.remote")
            
            // Wait briefly to see if pairing starts successfully
            // The callbacks will handle state updates
            // Give it 3 seconds to establish connection and show PIN
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            // Check current state
            let currentState = await MainActor.run { stateSubject.value }
            
            // If we're waiting for code, Android TV protocol is working!
            if case .pairing(.waitingForCode) = currentState {
                #if DEBUG
                print("[AndroidTVAdapter] Android TV Remote Protocol working - waiting for 6-digit PIN")
                #endif
                return // Successfully started Android TV pairing
            }
            
            // If we got an error, throw to trigger fallback
            if case .pairing(.failed(_)) = currentState {
                throw ConnectionError.pairingFailed("Android TV Remote Protocol failed")
            }
            
            // If still in starting state, might be slow connection - give it more time
            // But if it's a Sony TV and we've waited, might need to fall back
            if shouldFallbackToSony {
                #if DEBUG
                print("[AndroidTVAdapter] Still in starting state after 3s, will try fallback for Sony")
                #endif
                throw ConnectionError.pairingFailed("Android TV Remote Protocol timeout")
            }
            
            // If we get here without error, Android TV protocol is working
            #if DEBUG
            print("[AndroidTVAdapter] Android TV Remote Protocol pairing in progress")
            #endif
            return
            
        } catch {
            #if DEBUG
            print("[AndroidTVAdapter] Android TV Remote Protocol failed: \(error)")
            #endif
        }
        
        // Fall back to Sony REST API only if Android TV protocol failed and it's a Sony TV
        if shouldFallbackToSony {
            #if DEBUG
            print("[AndroidTVAdapter] Falling back to Sony REST API for pairing")
            #endif
            shouldFallbackToSony = false
            if sonyAdapter == nil {
                sonyAdapter = SonyBraviaAdapter(host: device.host, port: 80, authKey: "0000")
            }
            try await sonyAdapter!.startPairing(to: device)
        } else {
            // For non-Sony TVs, re-throw the error
            throw ConnectionError.pairingFailed("Android TV Remote Protocol failed")
        }
    }

    func submitPairingCode(_ code: String) async throws {
        // Validate code format (6 hex characters: 0-9, A-F)
        let validChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard code.count == 6, code.unicodeScalars.allSatisfy({ validChars.contains($0) }) else {
            throw ConnectionError.pairingFailed("Code must be 6 hex characters (0-9, A-F)")
        }
        
        // Check if using Sony adapter
        if let sonyAdapter = sonyAdapter, isSonyBravia(currentDevice ?? TVDevice(name: "", host: "", port: 0)) {
            try await sonyAdapter.submitPairingCode(code)
            return
        }
        
        // Use PairingManager from package
        guard let pairingManager = pairingManager else {
            throw ConnectionError.pairingFailed("No active pairing session")
        }
        
        await MainActor.run {
            stateSubject.send(.pairing(.validatingCode))
        }
        
        pairingManager.sendSecret(code.uppercased())
    }

    // MARK: - RemoteCommandProtocol

    func send(_ action: RemoteAction) async throws {
        #if DEBUG
        print("[AndroidTVAdapter] 📤 send() called with action: \(action), direction: .short")
        #endif
        try await send(action, direction: .short)
    }

    func send(_ action: RemoteAction, direction: KeyPressDirection) async throws {
        #if DEBUG
        print("[AndroidTVAdapter] 📤 send() called with action: \(action), direction: \(direction)")
        #endif
        
        guard let device = currentDevice else {
            #if DEBUG
            print("[AndroidTVAdapter] ❌ No current device set")
            #endif
            throw ConnectionError.deviceUnreachable
        }
        
        #if DEBUG
        print("[AndroidTVAdapter] Current device: \(device.name) at \(device.host)")
        print("[AndroidTVAdapter] Is Sony Bravia: \(isSonyBravia(device))")
        print("[AndroidTVAdapter] RemoteManager available: \(remoteManager != nil)")
        print("[AndroidTVAdapter] SonyAdapter available: \(sonyAdapter != nil)")
        #endif
        
        // Priority: Use RemoteManager if available (Android TV Remote Protocol)
        // Only fall back to Sony IRCC if RemoteManager is not available
        if let remoteManager = remoteManager {
            #if DEBUG
            print("[AndroidTVAdapter] ✅ Using Android TV RemoteManager (paired via Android TV protocol)")
            #endif
            
            // Map RemoteAction to package's Key enum
            guard let key = mapActionToKey(action) else {
                #if DEBUG
                print("[AndroidTVAdapter] ⚠️ Action not mapped to key, checking special cases")
                #endif
            // Handle text input and other special cases
            if case .textInput(let text) = action {
                #if DEBUG
                print("[AndroidTVAdapter] 📝 Sending text input: \(text)")
                print("[AndroidTVAdapter] Using IME batch edit method (imeCounter: \(imeCounter), fieldCounter: \(fieldCounter))")
                #endif
                
                // Use IME batch edit with counters from TV response
                // Increment counters for next use (TV will send updated counters in response)
                let currentImeCounter = imeCounter
                let currentFieldCounter = fieldCounter
                
                imeCounter += 1
                fieldCounter += 1
                
                let imeMessage = IMEBatchEdit(text: text, imeCounter: currentImeCounter, fieldCounter: currentFieldCounter)
                remoteManager.send(imeMessage)
                
                #if DEBUG
                print("[AndroidTVAdapter] ✅ IME batch edit sent for text: '\(text)'")
                print("[AndroidTVAdapter] Used counters - imeCounter: \(currentImeCounter), fieldCounter: \(currentFieldCounter)")
                print("[AndroidTVAdapter] Next counters will be - imeCounter: \(imeCounter), fieldCounter: \(fieldCounter)")
                #endif
                return
            }
                if case .openApp(let url) = action {
                    #if DEBUG
                    print("[AndroidTVAdapter] 🔗 Sending deep link: \(url)")
                    #endif
                    remoteManager.send(DeepLink(url))
                    return
                }
                #if DEBUG
                print("[AndroidTVAdapter] ❌ Action not supported: \(action)")
                #endif
                throw ConnectionError.deviceUnreachable
            }
            
            // Map direction
            let remoteDirection = mapDirection(direction)
            
            #if DEBUG
            print("[AndroidTVAdapter] 🎯 Mapped action \(action) to key: \(key), direction: \(remoteDirection)")
            print("[AndroidTVAdapter] 📡 Sending KeyPress to RemoteManager...")
            #endif
            
            // Send key press using package API
            remoteManager.send(KeyPress(key, remoteDirection))
            
            #if DEBUG
            print("[AndroidTVAdapter] ✅ KeyPress sent successfully: \(key) with direction \(remoteDirection)")
            #endif
            return
        }
        
        // Fallback: Use IRCC for Sony Bravia only if RemoteManager is not available
        if isSonyBravia(device), let sonyAdapter = sonyAdapter {
            #if DEBUG
            print("[AndroidTVAdapter] 🔄 Falling back to Sony IRCC adapter (RemoteManager not available)")
            #endif
            try await sonyAdapter.send(action, direction: direction)
            return
        }
        
        // No connection method available
        #if DEBUG
        print("[AndroidTVAdapter] ❌ No connection method available")
        print("[AndroidTVAdapter] RemoteManager: \(remoteManager != nil ? "exists" : "nil")")
        print("[AndroidTVAdapter] SonyAdapter: \(sonyAdapter != nil ? "exists" : "nil")")
        print("[AndroidTVAdapter] Current connection state: \(stateSubject.value)")
        #endif
        throw ConnectionError.deviceUnreachable
    }

    // MARK: - Action Mapping

    private func mapActionToKey(_ action: RemoteAction) -> Key? {
        let key: Key?
        switch action {
        // Navigation
        case .dpadUp: 
            key = .KEYCODE_DPAD_UP
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping dpadUp -> KEYCODE_DPAD_UP (19)")
            #endif
        case .dpadDown: 
            key = .KEYCODE_DPAD_DOWN
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping dpadDown -> KEYCODE_DPAD_DOWN (20)")
            #endif
        case .dpadLeft: 
            key = .KEYCODE_DPAD_LEFT
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping dpadLeft -> KEYCODE_DPAD_LEFT (21)")
            #endif
        case .dpadRight: 
            key = .KEYCODE_DPAD_RIGHT
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping dpadRight -> KEYCODE_DPAD_RIGHT (22)")
            #endif
        case .dpadCenter: 
            key = .KEYCODE_DPAD_CENTER
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping dpadCenter -> KEYCODE_DPAD_CENTER (23)")
            #endif
        
        // System
        case .home: 
            key = .KEYCODE_HOME
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping home -> KEYCODE_HOME (3)")
            #endif
        case .back: 
            key = .KEYCODE_BACK
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping back -> KEYCODE_BACK (4)")
            #endif
        case .menu: 
            key = .KEYCODE_MENU
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping menu -> KEYCODE_MENU (82)")
            #endif
        
        // Media
        case .playPause: 
            key = .KEYCODE_MEDIA_PLAY_PAUSE
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping playPause -> KEYCODE_MEDIA_PLAY_PAUSE (85)")
            #endif
        case .play: 
            key = .KEYCODE_MEDIA_PLAY
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping play -> KEYCODE_MEDIA_PLAY (126)")
            #endif
        case .pause: 
            key = .KEYCODE_MEDIA_PAUSE
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping pause -> KEYCODE_MEDIA_PAUSE (127)")
            #endif
        case .stop: 
            key = .KEYCODE_MEDIA_STOP
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping stop -> KEYCODE_MEDIA_STOP (86)")
            #endif
        case .next: 
            key = .KEYCODE_MEDIA_NEXT
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping next -> KEYCODE_MEDIA_NEXT (87)")
            #endif
        case .previous: 
            key = .KEYCODE_MEDIA_PREVIOUS
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping previous -> KEYCODE_MEDIA_PREVIOUS (88)")
            #endif
        case .rewind: 
            key = .KEYCODE_MEDIA_REWIND
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping rewind -> KEYCODE_MEDIA_REWIND (89)")
            #endif
        case .fastForward: 
            key = .KEYCODE_MEDIA_FAST_FORWARD
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping fastForward -> KEYCODE_MEDIA_FAST_FORWARD (90)")
            #endif
        
        // Volume
        case .volumeUp: 
            key = .KEYCODE_VOLUME_UP
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping volumeUp -> KEYCODE_VOLUME_UP (24)")
            #endif
        case .volumeDown: 
            key = .KEYCODE_VOLUME_DOWN
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping volumeDown -> KEYCODE_VOLUME_DOWN (25)")
            #endif
        case .mute: 
            key = .KEYCODE_MUTE
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping mute -> KEYCODE_MUTE (91)")
            #endif
        
        // Power
        case .power: 
            key = .KEYCODE_POWER
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping power -> KEYCODE_POWER (26)")
            #endif
        
        // Text input handled separately
        case .textInput, .deleteCharacter, .enter, .openApp:
            key = nil
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Action \(action) not mapped (handled separately)")
            #endif
        }
        return key
    }

    private func mapDirection(_ direction: KeyPressDirection) -> Direction {
        switch direction {
        case .short:
            return .SHORT
        case .startLong:
            return .START_LONG
        case .endLong:
            return .END_LONG
        }
    }

    // MARK: - Text Input

    private func sendText(_ text: String, remoteManager: RemoteManager) async throws {
        #if DEBUG
        print("[AndroidTVAdapter] 📝 sendText() called with text: '\(text)' (length: \(text.count))")
        #endif
        
        // Send each character as individual key presses
        for (index, character) in text.enumerated() {
            #if DEBUG
            print("[AndroidTVAdapter] 📝 Processing character \(index + 1)/\(text.count): '\(character)'")
            #endif
            
            if let key = mapCharacterToKey(character) {
                #if DEBUG
                print("[AndroidTVAdapter] 📝 Mapped '\(character)' to key: \(key) (rawValue: \(key.rawValue))")
                print("[AndroidTVAdapter] 📡 Sending KeyPress for character '\(character)'...")
                #endif
                
                remoteManager.send(KeyPress(key, .SHORT))
                
                #if DEBUG
                print("[AndroidTVAdapter] ✅ KeyPress sent for '\(character)'")
                #endif
                
                // Small delay between characters for reliability
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            } else if character == "\n" {
                #if DEBUG
                print("[AndroidTVAdapter] 📝 Sending ENTER key for newline")
                #endif
                remoteManager.send(KeyPress(.KEYCODE_ENTER, .SHORT))
                try await Task.sleep(nanoseconds: 50_000_000)
            } else if character == "\u{8}" || character == "\u{7F}" {
                #if DEBUG
                print("[AndroidTVAdapter] 📝 Sending DELETE key for backspace")
                #endif
                remoteManager.send(KeyPress(.KEYCODE_DEL, .SHORT))
                try await Task.sleep(nanoseconds: 50_000_000)
            } else {
                #if DEBUG
                print("[AndroidTVAdapter] ⚠️ Character '\(character)' not mapped, skipping")
                #endif
            }
        }
        
        #if DEBUG
        print("[AndroidTVAdapter] ✅ Finished sending text: '\(text)'")
        #endif
    }

    private func mapCharacterToKey(_ character: Character) -> Key? {
        let char = character.lowercased()
        let isUppercase = character.isUppercase
        
        #if DEBUG
        print("[AndroidTVAdapter] 🔤 mapCharacterToKey: '\(character)' (lowercase: '\(char)', uppercase: \(isUppercase))")
        #endif
        
        let key: Key?
        switch char {
        case "a": key = .KEYCODE_A
        case "b": key = .KEYCODE_B
        case "c": key = .KEYCODE_C
        case "d": key = .KEYCODE_D
        case "e": key = .KEYCODE_E
        case "f": key = .KEYCODE_F
        case "g": key = .KEYCODE_G
        case "h": key = .KEYCODE_H
        case "i": key = .KEYCODE_I
        case "j": key = .KEYCODE_J
        case "k": key = .KEYCODE_K
        case "l": key = .KEYCODE_L
        case "m": key = .KEYCODE_M
        case "n": key = .KEYCODE_N
        case "o": key = .KEYCODE_O
        case "p": key = .KEYCODE_P
        case "q": key = .KEYCODE_Q
        case "r": key = .KEYCODE_R
        case "s": key = .KEYCODE_S
        case "t": key = .KEYCODE_T
        case "u": key = .KEYCODE_U
        case "v": key = .KEYCODE_V
        case "w": key = .KEYCODE_W
        case "x": key = .KEYCODE_X
        case "y": key = .KEYCODE_Y
        case "z": key = .KEYCODE_Z
        case "0": key = .KEYCODE_0
        case "1": key = .KEYCODE_1
        case "2": key = .KEYCODE_2
        case "3": key = .KEYCODE_3
        case "4": key = .KEYCODE_4
        case "5": key = .KEYCODE_5
        case "6": key = .KEYCODE_6
        case "7": key = .KEYCODE_7
        case "8": key = .KEYCODE_8
        case "9": key = .KEYCODE_9
        case " ": key = .KEYCODE_SPACE
        case ".": key = .KEYCODE_PERIOD
        case ",": key = .KEYCODE_COMMA
        case "-": key = .KEYCODE_MINUS
        case "=": key = .KEYCODE_EQUALS
        case "[": key = .KEYCODE_LEFT_BRACKET
        case "]": key = .KEYCODE_RIGHT_BRACKET
        case "\\": key = .KEYCODE_BACKSLASH
        case ";": key = .KEYCODE_SEMICOLON
        case "'": key = .KEYCODE_APOSTROPHE
        case "/": key = .KEYCODE_SLASH
        case "@": key = .KEYCODE_AT
        case "+": key = .KEYCODE_PLUS
        default:
            key = nil
        }
        
        #if DEBUG
        if let mappedKey = key {
            print("[AndroidTVAdapter] 🔤 Mapped '\(character)' to key: \(mappedKey) (rawValue: \(mappedKey.rawValue))")
        } else {
            print("[AndroidTVAdapter] 🔤 No mapping found for '\(character)'")
        }
        #endif
        
        // For uppercase letters, Android TV Remote Protocol doesn't reliably support SHIFT
        // Most TVs will accept lowercase keys and the input field will handle case
        // If uppercase is needed, we could try SHIFT down + key + SHIFT up, but it's unreliable
        return key
    }
}
