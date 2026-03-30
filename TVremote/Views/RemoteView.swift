//
//  RemoteView.swift
//  TVremote
//
//  Main remote control interface
//

import SwiftUI

struct RemoteView: View {
    let device: TVDevice
    @State private var viewModel: RemoteViewModel
    @State private var showSettings = false

    init(device: TVDevice, adapter: any TVRemoteAdapterProtocol) {
        self.device = device
        _viewModel = State(initialValue: RemoteViewModel(adapter: adapter))
    }

    var body: some View {
        GeometryReader { geo in
            let mainStackSpacing = geo.size.height * 0.028

            ZStack {
                // Background
                backgroundGradient

                // Main content
                VStack(spacing: 0) {
                    // Top bar
                    RemoteTopBar(showSettings: $showSettings)

                    // Remote layout
                    VStack(spacing: mainStackSpacing) {
                        Spacer()

                        // Power button
                        powerButton(minSide: min(geo.size.width, geo.size.height))

                        // D-Pad
                        dPadSection

                        // System buttons
                        systemButtons(availableWidth: geo.size.width * 0.92)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
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

    // MARK: - Power Button

    private func powerButton(minSide: CGFloat) -> some View {
        let diameter = minSide * 0.108
        return Button(action: { viewModel.power() }) {
            Image(systemName: "power")
                .font(.system(size: diameter * 0.42, weight: .medium))
                .foregroundColor(.red)
                .frame(width: diameter, height: diameter)
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

    private func systemButtons(availableWidth: CGFloat) -> some View {
        systemButtonRow(spacing: max(16, min(availableWidth * 0.06, 28)))
    }

    private func systemButtonRow(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            systemButtonItems
        }
    }

    @ViewBuilder
    private var systemButtonItems: some View {
        backButton
        homeButton
        menuButton
    }

    private var backButton: some View {
        RemoteButton(icon: "arrow.uturn.backward", label: "Back") {
            viewModel.back()
        }
    }

    private var homeButton: some View {
        RemoteButton(icon: "house.fill", label: "Home") {
            viewModel.home()
        }
    }

    private var menuButton: some View {
        RemoteButton(icon: "line.3.horizontal", label: "Menu") {
            viewModel.menu()
        }
    }

    // Removed extra overlays and media/volume controls to reduce feature surface.
}

private struct RemoteTopBar: View {
    @Binding var showSettings: Bool
    @ObservedObject private var appViewModel: AppViewModel

    init(
        showSettings: Binding<Bool>,
        appViewModel: AppViewModel = .shared
    ) {
        _showSettings = showSettings
        _appViewModel = ObservedObject(wrappedValue: appViewModel)
    }

    var body: some View {
        HStack {
            Button(action: appViewModel.disconnect) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("TVs")
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }

            Spacer()

            StatusBadge(isConnected: appViewModel.connectionState.isConnected)

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(.systemGray))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    let device: TVDevice
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appViewModel: AppViewModel

    init(device: TVDevice, appViewModel: AppViewModel = .shared) {
        self.device = device
        _appViewModel = ObservedObject(wrappedValue: appViewModel)
    }

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
}
