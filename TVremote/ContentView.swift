//
//  ContentView.swift
//  TVremote
//
//  Main content view with state-driven navigation
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appViewModel = AppViewModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Background color
            Color.black.ignoresSafeArea()

            // Navigation based on state
            Group {
                switch appViewModel.navigationState {
                case .discovery:
                    DiscoveryView()
                        .transition(.opacity)

                case .pairing(let device):
                    PairingView(device: device)
                        .transition(.move(edge: .trailing))

                case .remote(let device):
                    RemoteView(device: device, adapter: appViewModel.adapter)
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appViewModel.navigationState)
        }
        .environmentObject(appViewModel)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            #if DEBUG
            print("[ContentView] Scene phase changed: \(oldPhase) -> \(newPhase)")
            #endif
            
            switch newPhase {
            case .background:
                // App went to background - keep connection alive
                #if DEBUG
                print("[ContentView] App went to background - maintaining connection")
                #endif
                // Don't disconnect - connection should stay alive
                
            case .inactive:
                // App is inactive (e.g., during transition)
                #if DEBUG
                print("[ContentView] App became inactive")
                #endif
                
            case .active:
                // App became active - check connection and reconnect if needed
                #if DEBUG
                print("[ContentView] App became active - checking connection")
                #endif
                Task {
                    await appViewModel.handleAppBecameActive()
                }
                
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
