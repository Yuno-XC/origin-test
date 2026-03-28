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

private enum PairingCodeValidation {
    static let hexScalars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
}

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

    // IME counter tracking for text input
    private var imeCounter: Int = 0
    private var imeFieldCounter: Int = 0

    /// Synchronizes `connectToRemote` with `RemoteManager` async state (connected / error / timeout).
    private let remoteWaitLock = NSLock()
    private var remoteWaitToken: UInt64 = 0
    private var activeRemoteWaitToken: UInt64?
    private var remoteWaitContinuation: CheckedContinuation<Void, Error>?

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
            
            DebugLogger.log(.adapter, "TLS trust closure called - extracting server certificate")

            // First, evaluate the trust to get the certificate chain
            var secresult: SecTrustResultType = .invalid
            let status = SecTrustEvaluate(secTrust, &secresult)

            guard status == errSecSuccess else {
                DebugLogger.logError(.adapter, "SecTrustEvaluate failed with status: \(status)")
                return
            }

            // Get the certificate count
            let certCount = SecTrustGetCertificateCount(secTrust)
            guard certCount > 0 else {
                DebugLogger.logWarning(.adapter, "No certificates in trust chain")
                return
            }

            // Get the first certificate (server's certificate)
            guard let serverCert = SecTrustGetCertificateAtIndex(secTrust, 0) else {
                DebugLogger.logError(.adapter, "Failed to get server certificate from trust chain")
                return
            }

            // Extract public key from the certificate
            guard let serverKey = SecCertificateCopyKey(serverCert) else {
                DebugLogger.logError(.adapter, "Failed to extract public key from server certificate")
                return
            }

            DebugLogger.logSuccess(.adapter, "Successfully extracted server public key")
            
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
        
        DebugLogger.logSuccess(.adapter, "RemoteManager created and stored")
        DebugLogger.log(.adapter, "RemoteManager instance: \(remoteManager != nil ? "exists" : "nil")")

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
                    DebugLogger.log(.pairing, "Waiting for 6-digit code on TV")
                    self.stateSubject.send(.pairing(.waitingForCode))

                case .secretSent:
                    DebugLogger.log(.pairing, "Secret sent, validating...")
                    self.stateSubject.send(.pairing(.validatingCode))

                case .successPaired:
                    DebugLogger.logSuccess(.pairing, "Successfully paired!")
                    DebugLogger.log(.pairing, "Current device: \(self.currentDevice?.name ?? "nil")")
                    DebugLogger.log(.pairing, "RemoteManager exists: \(self.remoteManager != nil)")
                    DebugLogger.log(.pairing, "CryptoManager exists: \(self.cryptoManager != nil)")
                    DebugLogger.log(.pairing, "TLSManager exists: \(self.tlsManager != nil)")
                    self.isPairing = false
                    self.stateSubject.send(.pairing(.success))
                    // Remote session is started from AppViewModel.connect after submitPairingCode.
                    // Avoid a second connectToRemote here — parallel connects caused flaky handshakes.

                case .error(let error):
                    DebugLogger.logError(.pairing, "Pairing error: \(error)")
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
                DebugLogger.logState(.remote, "RemoteManager state changed: \(state)")

                switch state {
                case .connected:
                    DebugLogger.logSuccess(.remote, "Connected and ready")
                    self.resolveRemoteHandshakeWait(with: .success(()))
                    self.stateSubject.send(.connected)

                case .paired(let runningApp):
                    DebugLogger.logSuccess(.remote, "Paired, running app: \(runningApp ?? "Unknown")")
                    self.resolveRemoteHandshakeWait(with: .success(()))
                    self.stateSubject.send(.connected)

                case .error(let error):
                    DebugLogger.logError(.remote, "Remote error: \(error)")
                    self.resolveRemoteHandshakeWait(with: .failure(ConnectionError.connectionLost))
                    self.stateSubject.send(.error(.connectionLost))

                default:
                    DebugLogger.log(.remote, "Remote state: \(state)")
                    break
                }
            }
        }

        // Handle received data to track IME counters
        remoteManager?.receiveData = { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            guard data.count >= 4 else { return }
            self.parseReceivedData(data)
        }
    }

    /// Parse received data for IME batch edit messages to update counters
    private func parseReceivedData(_ data: Data) {
        guard let (ime, field) = RemoteImeProtobuf.imeCounters(from: data) else { return }
        imeCounter = ime
        imeFieldCounter = field
        DebugLogger.logReceived(.adapter, "IME counters - ime: \(ime), field: \(field)")
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

    private func resolveRemoteHandshakeWait(with result: Swift.Result<Void, Error>) {
        remoteWaitLock.lock()
        let continuation = remoteWaitContinuation
        remoteWaitContinuation = nil
        activeRemoteWaitToken = nil
        remoteWaitLock.unlock()

        guard let continuation else { return }

        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func connectToRemote() async throws {
        guard let remoteManager = remoteManager,
              let device = currentDevice else {
            DebugLogger.logError(.adapter, "connectToRemote: Missing remoteManager or currentDevice")
            DebugLogger.log(.adapter, "remoteManager: \(remoteManager != nil ? "exists" : "nil")")
            DebugLogger.log(.adapter, "currentDevice: \(currentDevice?.name ?? "nil")")
            throw ConnectionError.deviceUnreachable
        }

        DebugLogger.logSuccess(.adapter, "connectToRemote: Connecting to \(device.name) at \(device.host)")

        await MainActor.run {
            stateSubject.send(.connecting)
        }

        remoteManager.connect(device.host)
    }

    // MARK: - TVConnectionProtocol

    func connect(to device: TVDevice) async throws {
        DebugLogger.logConnection(.adapter, "connect() called for device: \(device.name) at \(device.host)")
        DebugLogger.log(.adapter, "Setting currentDevice to: \(device.name)")

        currentDevice = device

        DebugLogger.log(.adapter, "currentDevice is now: \(currentDevice?.name ?? "nil")")
        DebugLogger.log(.adapter, "RemoteManager available: \(remoteManager != nil)")
        DebugLogger.log(.adapter, "Is Sony Bravia: \(isSonyBravia(device))")

        // Priority: If RemoteManager is already set up (from Android TV pairing), use it
        // This takes precedence even for Sony TVs that were paired via Android TV protocol
        if let existingRemoteManager = remoteManager {
            DebugLogger.logSuccess(.adapter, "RemoteManager already set up from pairing, reusing it")

            // Check if already connected
            let currentState = stateSubject.value
            if case .connected = currentState {
                DebugLogger.log(.adapter, "Already connected via RemoteManager")
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
            DebugLogger.log(.adapter, "Device is paired but RemoteManager not set up, initializing...")
            DebugLogger.log(.adapter, "Device was paired via Android TV protocol, setting up RemoteManager")
            try setupManagers(for: device)

            DebugLogger.log(.adapter, "RemoteManager after setup: \(remoteManager != nil ? "exists" : "nil")")

            // Connect to remote
            try await connectToRemote()
            return
        }

        // Fallback: For Sony Bravia without pairing, try IRCC
        if isSonyBravia(device) {
            DebugLogger.log(.adapter, "No pairing, falling back to IRCC protocol for Sony")
            if sonyAdapter == nil {
                sonyAdapter = SonyBraviaAdapter(host: device.host, port: 80, authKey: "0000")
            }
            try await sonyAdapter!.connect(to: device)
            stateSubject.send(.connected)
            return
        }

        // For Android TV without pairing, set it up now
        DebugLogger.log(.adapter, "Setting up RemoteManager for Android TV (not paired)")
        try setupManagers(for: device)

        // Only connect if not already connected
        let currentState = stateSubject.value
        if case .connected = currentState {
            DebugLogger.log(.adapter, "Already connected, skipping connectToRemote")
            return
        }

        try await connectToRemote()
    }

    func disconnect() {
        DebugLogger.logConnection(.adapter, "disconnect() called")
        DebugLogger.log(.adapter, "RemoteManager before disconnect: \(remoteManager != nil ? "exists" : "nil")")
        DebugLogger.log(.adapter, "Clearing RemoteManager and other managers")

        pairingManager = nil
        remoteManager?.disconnect()
        remoteManager = nil
        cryptoManager = nil
        tlsManager = nil
        sonyAdapter?.disconnect()
        sonyAdapter = nil
        currentDevice = nil
        isPairing = false
        resetIMECounters()
        stateSubject.send(.disconnected)

        DebugLogger.log(.adapter, "RemoteManager after disconnect: \(remoteManager != nil ? "exists" : "nil")")
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
        guard code.count == 6, code.unicodeScalars.allSatisfy({ PairingCodeValidation.hexScalars.contains($0) }) else {
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
                    #endif
                    try await sendText(text, remoteManager: remoteManager)
                    return
                }
                if case .deleteCharacter = action {
                    #if DEBUG
                    print("[AndroidTVAdapter] 🗑️ Sending delete (backspace)")
                    #endif
                    remoteManager.send(KeyPress(.KEYCODE_DEL, mapDirection(direction)))
                    return
                }
                if case .enter = action {
                    #if DEBUG
                    print("[AndroidTVAdapter] ⏎ Sending enter key")
                    #endif
                    remoteManager.send(KeyPress(.KEYCODE_ENTER, mapDirection(direction)))
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

        // Channel
        case .channelDigit(let digit):
            key = mapChannelDigitToKey(digit)
            #if DEBUG
            print("[AndroidTVAdapter] 🗺️ Mapping channelDigit(\(digit)) -> \(String(describing: key))")
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

    private func mapChannelDigitToKey(_ digit: Int) -> Key? {
        switch digit {
        case 0: return .KEYCODE_0
        case 1: return .KEYCODE_1
        case 2: return .KEYCODE_2
        case 3: return .KEYCODE_3
        case 4: return .KEYCODE_4
        case 5: return .KEYCODE_5
        case 6: return .KEYCODE_6
        case 7: return .KEYCODE_7
        case 8: return .KEYCODE_8
        case 9: return .KEYCODE_9
        default: return nil
        }
    }

    // MARK: - Text Input

    private func sendText(_ text: String, remoteManager: RemoteManager) async throws {
        #if DEBUG
        print("[AndroidTVAdapter] 📝 Sending text input using IME batch edit protocol: '\(text)'")
        print("[AndroidTVAdapter] Using ime_counter: \(imeCounter), field_counter: \(imeFieldCounter)")
        #endif

        // Use the proper text input protocol (RemoteImeBatchEdit - field 21)
        // Based on https://github.com/tronikos/androidtvremote2
        let textInput = TextInput(text, imeCounter: imeCounter, fieldCounter: imeFieldCounter)
        remoteManager.send(textInput)

        #if DEBUG
        print("[AndroidTVAdapter] ✅ Text input sent successfully")
        #endif
    }

    /// Update IME counters from received data
    /// Call this when receiving remote_ime_batch_edit messages from TV
    func updateIMECounters(imeCounter: Int, fieldCounter: Int) {
        self.imeCounter = imeCounter
        self.imeFieldCounter = fieldCounter
        #if DEBUG
        print("[AndroidTVAdapter] Updated IME counters - ime: \(imeCounter), field: \(fieldCounter)")
        #endif
    }

    /// Reset IME counters (call when disconnecting)
    private func resetIMECounters() {
        imeCounter = 0
        imeFieldCounter = 0
    }

    private func mapCharacterToKey(_ character: Character) -> Key? {
        let char = character.lowercased()
        
        switch char {
        case "a": return .KEYCODE_A
        case "b": return .KEYCODE_B
        case "c": return .KEYCODE_C
        case "d": return .KEYCODE_D
        case "e": return .KEYCODE_E
        case "f": return .KEYCODE_F
        case "g": return .KEYCODE_G
        case "h": return .KEYCODE_H
        case "i": return .KEYCODE_I
        case "j": return .KEYCODE_J
        case "k": return .KEYCODE_K
        case "l": return .KEYCODE_L
        case "m": return .KEYCODE_M
        case "n": return .KEYCODE_N
        case "o": return .KEYCODE_O
        case "p": return .KEYCODE_P
        case "q": return .KEYCODE_Q
        case "r": return .KEYCODE_R
        case "s": return .KEYCODE_S
        case "t": return .KEYCODE_T
        case "u": return .KEYCODE_U
        case "v": return .KEYCODE_V
        case "w": return .KEYCODE_W
        case "x": return .KEYCODE_X
        case "y": return .KEYCODE_Y
        case "z": return .KEYCODE_Z
        case "0": return .KEYCODE_0
        case "1": return .KEYCODE_1
        case "2": return .KEYCODE_2
        case "3": return .KEYCODE_3
        case "4": return .KEYCODE_4
        case "5": return .KEYCODE_5
        case "6": return .KEYCODE_6
        case "7": return .KEYCODE_7
        case "8": return .KEYCODE_8
        case "9": return .KEYCODE_9
        case " ": return .KEYCODE_SPACE
        case ".": return .KEYCODE_PERIOD
        case ",": return .KEYCODE_COMMA
        case "-": return .KEYCODE_MINUS
        case "=": return .KEYCODE_EQUALS
        case "[": return .KEYCODE_LEFT_BRACKET
        case "]": return .KEYCODE_RIGHT_BRACKET
        case "\\": return .KEYCODE_BACKSLASH
        case ";": return .KEYCODE_SEMICOLON
        case "'": return .KEYCODE_APOSTROPHE
        case "/": return .KEYCODE_SLASH
        case "@": return .KEYCODE_AT
        case "+": return .KEYCODE_PLUS
        default:
            return nil
        }
    }
}
