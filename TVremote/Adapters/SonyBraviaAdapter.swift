//
//  SonyBraviaAdapter.swift
//  TVremote
//
//  Sony Bravia adapter using IRCC protocol
//

import Foundation
import Combine
import UIKit

/// Sony Bravia adapter using IRCC (Infrared Remote Control Command) over IP
final class SonyBraviaAdapter: TVRemoteAdapterProtocol {
    // MARK: - Properties
    
    private let ircc: SonyBraviaIRCC
    private let restAPI: SonyBraviaREST
    private var stateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    
    private(set) var currentDevice: TVDevice?
    private var authToken: String?
    private var pairingCode: String?
    
    var connectionState: AnyPublisher<ConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    var currentState: ConnectionState {
        get {
            return stateSubject.value
        }
    }
    
    // MARK: - Initialization
    
    init(host: String, port: UInt16 = 80, authKey: String = "0000") {
        // IRCC always uses port 80 (HTTP), regardless of device port
        self.ircc = SonyBraviaIRCC(host: host, port: 80, authKey: authKey)
        self.restAPI = SonyBraviaREST(host: host, port: 80, authKey: authKey)
    }
    
    // MARK: - TVConnectionProtocol
    
    func connect(to device: TVDevice) async throws {
        currentDevice = device
        // IRCC doesn't require pairing - just mark as connected
        // We'll test the connection when the first command is sent
        await MainActor.run {
            stateSubject.send(.connected)
        }
    }
    
    func disconnect() {
        currentDevice = nil
        stateSubject.send(.disconnected)
    }
    
    func startPairing(to device: TVDevice) async throws {
        currentDevice = device
        
        // Use REST API actRegister for pairing - format that triggers 6-digit code
        // Format: "AppName:unique-id" for clientId
        let appName = "GojoRemote"
        let uniqueId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let clientId = "\(appName):\(uniqueId)"
        let nickname = UIDevice.current.name
        
        #if DEBUG
        print("[SonyBraviaAdapter] Starting REST API pairing with actRegister")
        print("[SonyBraviaAdapter] Client ID: \(clientId), Nickname: \(nickname)")
        #endif
        
        do {
            // Send actRegister - this should trigger 6-digit code on TV
            let success = try await restAPI.actRegister(clientId: clientId, nickname: nickname)
            
            if success {
                // Store clientId for PIN submission
                self.authToken = clientId
                
                // Wait for user to enter PIN code
                await MainActor.run {
                    stateSubject.send(.pairing(.waitingForCode))
                }
            }
        } catch let error as SonyBraviaError {
            #if DEBUG
            print("[SonyBraviaAdapter] REST API pairing failed: \(error)")
            #endif
            
            // Re-throw with user-friendly message
            if case .restAPIError(let code, let message) = error {
                throw ConnectionError.pairingFailed(message)
            } else {
                throw ConnectionError.pairingFailed(error.localizedDescription)
            }
        } catch {
            #if DEBUG
            print("[SonyBraviaAdapter] REST API pairing failed: \(error)")
            #endif
            throw ConnectionError.pairingFailed(error.localizedDescription)
        }
    }
    
    func submitPairingCode(_ code: String) async throws {
        // Validate PIN is 4 or 6 digits (Sony TVs can show either)
        guard (code.count == 4 || code.count == 6), code.allSatisfy({ $0.isNumber }) else {
            throw ConnectionError.pairingFailed("PIN must be 4 or 6 digits")
        }
        
        guard let clientId = authToken else {
            throw ConnectionError.pairingFailed("No active pairing session")
        }
        
        let nickname = UIDevice.current.name
        
        #if DEBUG
        print("[SonyBraviaAdapter] Submitting 6-digit PIN: \(code)")
        #endif
        
        do {
            // Submit PIN with Basic Auth
            let success = try await restAPI.submitPIN(clientId: clientId, nickname: nickname, pin: code)
            
            if success {
                #if DEBUG
                print("[SonyBraviaAdapter] PIN submission successful - pairing complete")
                #endif
                
                self.pairingCode = code
                
                // Get and share the authentication cookie with IRCC
                if let cookie = restAPI.getAuthCookie() {
                    ircc.setAuthCookie(cookie)
                    #if DEBUG
                    print("[SonyBraviaAdapter] Authentication cookie shared with IRCC service")
                    #endif
                }
                
                await MainActor.run {
                    stateSubject.send(.pairing(.success))
                    stateSubject.send(.connected)
                }
            }
        } catch {
            #if DEBUG
            print("[SonyBraviaAdapter] PIN submission failed: \(error)")
            #endif
            throw ConnectionError.pairingFailed("PIN submission failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - RemoteCommandProtocol
    
    func send(_ action: RemoteAction) async throws {
        try await send(action, direction: .short)
    }
    
    func send(_ action: RemoteAction, direction: KeyPressDirection) async throws {
        guard let keyCode = mapActionToKeyCode(action) else {
            throw ConnectionError.deviceUnreachable
        }
        
        guard let irccCode = ircc.getIRCCCode(for: keyCode) else {
            throw ConnectionError.deviceUnreachable
        }
        
        try await ircc.sendIRCCCommand(irccCode)
    }
    
    // MARK: - Private
    
    private func mapActionToKeyCode(_ action: RemoteAction) -> AndroidKeyCode? {
        switch action {
        case .dpadUp: return .dpadUp
        case .dpadDown: return .dpadDown
        case .dpadLeft: return .dpadLeft
        case .dpadRight: return .dpadRight
        case .dpadCenter: return .dpadCenter
        case .home: return .home
        case .back: return .back
        case .menu: return .menu
        case .playPause: return .mediaPlayPause
        case .play: return .mediaPlay
        case .pause: return .mediaPause
        case .stop: return .mediaStop
        case .next: return .mediaNext
        case .previous: return .mediaPrevious
        case .rewind: return .mediaRewind
        case .fastForward: return .mediaFastForward
        case .volumeUp: return .volumeUp
        case .volumeDown: return .volumeDown
        case .mute: return .mute
        case .power: return .power
        case .textInput, .deleteCharacter, .enter, .openApp:
            // IRCC doesn't support text input directly
            return nil
        }
    }
}
