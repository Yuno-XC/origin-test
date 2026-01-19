//
//  DiscoveryView.swift
//  TVremote
//
//  Device discovery and selection screen
//

import SwiftUI

struct DiscoveryView: View {
    @StateObject private var viewModel = DiscoveryViewModel()
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Scanning indicator
                            if viewModel.isScanning {
                                scanningView
                            }

                            // Saved devices
                            if !viewModel.savedDevices.isEmpty {
                                savedDevicesSection
                            }

                            // Discovered devices
                            if !viewModel.devices.isEmpty {
                                discoveredDevicesSection
                            }

                            // Empty state
                            if !viewModel.hasDevices && !viewModel.isScanning {
                                emptyStateView
                            }

                            // Manual entry
                            manualEntryButton
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.startScanning()
                viewModel.onDeviceSelected = { device in
                    Task {
                        await appViewModel.connect(to: device)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showManualEntry) {
                ManualEntrySheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tv")
                .font(.system(size: 48))
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("TV Remote")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Select your Android TV")
                .font(.subheadline)
                .foregroundColor(Color(.systemGray))
        }
        .padding(.bottom, 24)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))

            Text("Scanning for TVs...")
                .font(.subheadline)
                .foregroundColor(Color(.systemGray))

            Spacer()

            Button("Stop") {
                viewModel.stopScanning()
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }

    // MARK: - Saved Devices Section

    private var savedDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SAVED TVs")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color(.systemGray))

            ForEach(viewModel.savedDevices) { device in
                DeviceRow(
                    device: device,
                    isSaved: true,
                    onTap: {
                        viewModel.selectDevice(device)
                    },
                    onDelete: {
                        viewModel.removeDevice(device)
                    }
                )
            }
        }
    }

    // MARK: - Discovered Devices Section

    private var discoveredDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DISCOVERED")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color(.systemGray))

            ForEach(viewModel.devices.filter { device in
                !viewModel.savedDevices.contains { $0.host == device.host }
            }) { device in
                DeviceRow(
                    device: device,
                    isSaved: false,
                    onTap: {
                        viewModel.selectDevice(device)
                    },
                    onDelete: nil
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(Color(.systemGray3))

            Text("No TVs Found")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Make sure your Android TV is on\nand connected to the same Wi-Fi network")
                .font(.subheadline)
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)

            Button(action: {
                viewModel.startScanning()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Scan Again")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Manual Entry Button

    private var manualEntryButton: some View {
        Button(action: {
            viewModel.showManualEntry = true
        }) {
            HStack {
                Image(systemName: "plus.circle")
                Text("Enter IP Address Manually")
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .padding(.top, 16)
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: TVDevice
    let isSaved: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // TV Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 48, height: 48)

                    Image(systemName: "tv")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                // Device info
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Text(device.host)
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                }

                Spacer()

                // Status / Delete
                HStack(spacing: 12) {
                    if device.isPaired {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(.systemGray3))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isPressed ? Color(.systemGray5) : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Manual Entry Sheet

struct ManualEntrySheet: View {
    @ObservedObject var viewModel: DiscoveryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var skipPairing = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Instructions
                    VStack(spacing: 8) {
                        Image(systemName: "number")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)

                        Text("Enter TV IP Address")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Find the IP address in your TV's\nNetwork Settings")
                            .font(.subheadline)
                            .foregroundColor(Color(.systemGray))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Text field
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("192.168.1.100", text: $viewModel.manualIP)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )

                        if let error = viewModel.manualIPError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)

                    // Skip pairing toggle
                    Toggle(isOn: $skipPairing) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connect directly (skip pairing)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text("Use if TV was already paired with another app")
                                .font(.caption)
                                .foregroundColor(Color(.systemGray))
                        }
                    }
                    .tint(.blue)
                    .padding(.horizontal)

                    // Connect button
                    Button(action: {
                        viewModel.connectManually(skipPairing: skipPairing)
                    }) {
                        Text(skipPairing ? "Connect Directly" : "Connect & Pair")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
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
    DiscoveryView()
        .environmentObject(AppViewModel.shared)
}
