//
//  RemoteView.swift
//  TVremote
//
//  Main remote control interface
//

import SwiftUI

struct RemoteView: View {
    let device: TVDevice
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: RemoteViewModel

    @State private var showKeyboard = false
    @State private var showSettings = false

    init(device: TVDevice, adapter: AndroidTVAdapter) {
        self.device = device
        _viewModel = StateObject(wrappedValue: RemoteViewModel(adapter: adapter))
    }

    var body: some View {
        ZStack {
            // Background
            backgroundGradient

            // Main content
            VStack(spacing: 0) {
                // Top bar
                topBar

                // Remote layout
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Volume control (left side)
                        volumeControl
                            .frame(width: 70)

                        // Main controls (center)
                        VStack(spacing: 24) {
                            Spacer()

                            // Power button
                            powerButton

                            // D-Pad
                            dPadSection

                            // System buttons
                            systemButtons

                            // Media controls
                            mediaControls

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)

                        // Placeholder for symmetry
                        Color.clear
                            .frame(width: 70)
                    }
                }
            }

            // Keyboard overlay
            if showKeyboard {
                FullScreenKeyboardView(
                    isPresented: $showKeyboard,
                    onSendCharacter: { viewModel.sendCharacter($0) },
                    onDelete: { viewModel.deleteCharacter() },
                    onEnter: { viewModel.sendEnter() }
                )
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(device: device)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemGray6),
                Color.black,
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Back button
            Button(action: {
                appViewModel.disconnect()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("TVs")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }

            Spacer()

            // Connection status
            StatusBadge(isConnected: appViewModel.connectionState.isConnected)

            Spacer()

            // Settings button
            Button(action: { showSettings = true }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundColor(Color(.systemGray))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        VStack {
            Spacer()

            VolumeControlView(
                onVolumeUp: { viewModel.volumeUp() },
                onVolumeDown: { viewModel.volumeDown() },
                onMute: { viewModel.mute() }
            )

            Spacer()
        }
        .padding(.leading, 12)
    }

    // MARK: - Power Button

    private var powerButton: some View {
        Button(action: { viewModel.power() }) {
            Image(systemName: "power")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.red)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )
        }
    }

    // MARK: - D-Pad Section

    private var dPadSection: some View {
        DPadView(
            onUp: { viewModel.dpadUp() },
            onDown: { viewModel.dpadDown() },
            onLeft: { viewModel.dpadLeft() },
            onRight: { viewModel.dpadRight() },
            onCenter: { viewModel.dpadCenter() }
        )
    }

    // MARK: - System Buttons

    private var systemButtons: some View {
        HStack(spacing: 40) {
            // Back
            RemoteButton(icon: "arrow.uturn.backward", label: "Back") {
                viewModel.back()
            }

            // Home
            RemoteButton(icon: "house.fill", label: "Home") {
                viewModel.home()
            }

            // Keyboard
            RemoteButton(icon: "keyboard", label: "Type") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showKeyboard = true
                }
            }
        }
    }

    // MARK: - Media Controls

    private var mediaControls: some View {
        MediaControlsView(
            onPlayPause: { viewModel.playPause() },
            onRewind: { viewModel.rewind() },
            onFastForward: { viewModel.fastForward() },
            onRewindRelease: { viewModel.stopRewind() },
            onFastForwardRelease: { viewModel.stopFastForward() },
            onPrevious: { viewModel.previous() },
            onNext: { viewModel.next() }
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    let device: TVDevice
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    // Device info
                    Section {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(device.name)
                                .foregroundColor(Color(.systemGray))
                        }

                        HStack {
                            Text("IP Address")
                            Spacer()
                            Text(device.host)
                                .foregroundColor(Color(.systemGray))
                        }

                        HStack {
                            Text("Status")
                            Spacer()
                            Text(device.isPaired ? "Paired" : "Not Paired")
                                .foregroundColor(device.isPaired ? .green : Color(.systemGray))
                        }
                    } header: {
                        Text("Device")
                    }
                    .listRowBackground(Color(.systemGray6))

                    // Actions
                    Section {
                        Button(action: {
                            dismiss()
                            appViewModel.disconnect()
                        }) {
                            HStack {
                                Image(systemName: "arrow.left.circle")
                                    .foregroundColor(.blue)
                                Text("Disconnect")
                                    .foregroundColor(.white)
                            }
                        }

                        Button(role: .destructive, action: {
                            PersistenceService.shared.removeDevice(device)
                            dismiss()
                            appViewModel.disconnect()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Forget This TV")
                            }
                        }
                    } header: {
                        Text("Actions")
                    }
                    .listRowBackground(Color(.systemGray6))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    RemoteView(
        device: TVDevice(name: "Living Room TV", host: "192.168.1.100", isPaired: true),
        adapter: AndroidTVAdapter()
    )
    .environmentObject(AppViewModel.shared)
}
