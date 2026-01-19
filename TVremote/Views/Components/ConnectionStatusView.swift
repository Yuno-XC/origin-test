//
//  ConnectionStatusView.swift
//  TVremote
//
//  Connection status indicator
//

import SwiftUI

struct ConnectionStatusView: View {
    let state: ConnectionState
    let deviceName: String?

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.5), radius: 4)

            // Status text
            VStack(alignment: .leading, spacing: 2) {
                if let name = deviceName {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }

                Text(state.displayText)
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
            }

            Spacer()

            // Reconnect button if disconnected
            if case .error = state {
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }

    private var statusColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting, .pairing:
            return .orange
        case .disconnected:
            return Color(.systemGray)
        case .error:
            return .red
        }
    }
}

// MARK: - Minimal Status Badge

struct StatusBadge: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color(.systemGray))
                .frame(width: 6, height: 6)

            Text(isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(Color(.systemGray))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            ConnectionStatusView(
                state: .connected,
                deviceName: "Living Room TV"
            )

            ConnectionStatusView(
                state: .connecting,
                deviceName: "Bedroom TV"
            )

            ConnectionStatusView(
                state: .error(.deviceUnreachable),
                deviceName: nil
            )

            StatusBadge(isConnected: true)
            StatusBadge(isConnected: false)
        }
        .padding()
    }
}
