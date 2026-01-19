//
//  PairingView.swift
//  TVremote
//
//  Pairing flow with code entry
//

import SwiftUI

struct PairingView: View {
    let device: TVDevice
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var code = ""
    @State private var showError = false
    @FocusState private var isCodeFocused: Bool

    private let codeLength = 6

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Header
                headerView

                // Code entry
                codeEntryView

                // Status
                statusView

                Spacer()

                // Buttons
                buttonsView
            }
            .padding()
        }
        .onAppear {
            startPairing()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "link")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }

            Text("Pair with TV")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Enter the code shown on \(device.name)")
                .font(.subheadline)
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Code Entry

    private var codeEntryView: some View {
        VStack(spacing: 16) {
            // Code boxes
            HStack(spacing: 12) {
                ForEach(0..<codeLength, id: \.self) { index in
                    CodeBox(
                        character: characterAt(index),
                        isActive: index == code.count && isPairingState
                    )
                }
            }

            // Hidden text field
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .focused($isCodeFocused)
                .opacity(0)
                .frame(height: 1)
                .onChange(of: code) { _, newValue in
                    // Filter to valid characters and limit length
                    let filtered = newValue
                        .uppercased()
                        .filter { "0123456789ABCDEF".contains($0) }
                        .prefix(codeLength)
                    code = String(filtered)

                    // Auto-submit when complete
                    if code.count == codeLength {
                        submitCode()
                    }
                }
        }
        .onTapGesture {
            isCodeFocused = true
        }
    }

    private func characterAt(_ index: Int) -> Character? {
        guard index < code.count else { return nil }
        return code[code.index(code.startIndex, offsetBy: index)]
    }

    // MARK: - Status

    private var statusView: some View {
        Group {
            switch appViewModel.connectionState {
            case .pairing(let state):
                switch state {
                case .starting:
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        Text("Connecting to TV...")
                            .font(.subheadline)
                            .foregroundColor(Color(.systemGray))
                    }

                case .waitingForCode:
                    Text("Look for the code on your TV screen")
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))

                case .validatingCode:
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        Text("Validating...")
                            .font(.subheadline)
                            .foregroundColor(Color(.systemGray))
                    }

                case .success:
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Paired successfully!")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }

                case .failed(let reason):
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(reason)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }

            case .error(let error):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Text(error.recoveryHint)
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                }

            default:
                EmptyView()
            }
        }
    }

    private var isPairingState: Bool {
        if case .pairing(let state) = appViewModel.connectionState {
            if case .waitingForCode = state { return true }
        }
        return false
    }

    // MARK: - Buttons

    private var buttonsView: some View {
        VStack(spacing: 12) {
            // Retry button (if failed)
            if case .pairing(let state) = appViewModel.connectionState,
               case .failed = state {
                Button(action: {
                    code = ""
                    startPairing()
                }) {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            // Skip pairing button - for TVs already paired with another device
            Button(action: {
                appViewModel.skipPairingAndConnect(device: device)
            }) {
                VStack(spacing: 4) {
                    Text("No code on TV?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    Text("Try connecting without pairing")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Cancel button
            Button(action: {
                appViewModel.cancelPairing()
            }) {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func startPairing() {
        isCodeFocused = true
        Task {
            await appViewModel.startPairing(for: device)
        }
    }

    private func submitCode() {
        isCodeFocused = false
        Task {
            await appViewModel.submitPairingCode(code)
        }
    }
}

// MARK: - Code Box

struct CodeBox: View {
    let character: Character?
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(width: 48, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isActive ? Color.blue : Color.clear,
                            lineWidth: 2
                        )
                )

            if let char = character {
                Text(String(char))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            } else if isActive {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 2, height: 24)
                    .opacity(isActive ? 1 : 0)
                    .animation(
                        Animation.easeInOut(duration: 0.5).repeatForever(),
                        value: isActive
                    )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PairingView(device: TVDevice(name: "Living Room TV", host: "192.168.1.100"))
        .environmentObject(AppViewModel.shared)
}
