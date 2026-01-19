//
//  ContentView.swift
//  TVremote
//
//  Main content view with state-driven navigation
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appViewModel = AppViewModel.shared

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
    }
}

#Preview {
    ContentView()
}
