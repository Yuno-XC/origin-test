//
//  RemoteButton.swift
//  TVremote
//
//  Reusable remote control button with haptic feedback
//

import SwiftUI
import UIKit

@MainActor
private enum SharedHaptics {
    static let medium = UIImpactFeedbackGenerator(style: .medium)
    static let light = UIImpactFeedbackGenerator(style: .light)

    static func impactMedium() {
        medium.impactOccurred()
        medium.prepare()
    }

    static func impactLight() {
        light.impactOccurred()
        light.prepare()
    }
}

struct RemoteButton: View {
    let icon: String
    let label: String?
    let action: () -> Void
    var longPressAction: (() -> Void)?
    var onRelease: (() -> Void)?

    @State private var isPressed = false
    init(
        icon: String,
        label: String? = nil,
        action: @escaping () -> Void,
        longPressAction: (() -> Void)? = nil,
        onRelease: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.label = label
        self.action = action
        self.longPressAction = longPressAction
        self.onRelease = onRelease
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isPressed
                                ? [Color(.systemGray4), Color(.systemGray5)]
                                : [Color(.systemGray5), Color(.systemGray6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: .black.opacity(isPressed ? 0.1 : 0.25),
                        radius: isPressed ? 2 : 4,
                        y: isPressed ? 1 : 2
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }

            if let label = label {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(Color(.systemGray))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        SharedHaptics.impactMedium()

                        if longPressAction != nil {
                            longPressAction?()
                        }
                    }
                }
                .onEnded { _ in
                    isPressed = false

                    if longPressAction != nil {
                        onRelease?()
                    } else {
                        action()
                    }
                }
        )
    }
}

// MARK: - Icon Button (Smaller variant)

struct IconButton: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(isPressed ? .white : Color(.systemGray))
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(isPressed ? Color(.systemGray5) : Color.clear)
            )
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            SharedHaptics.impactLight()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

// MARK: - Volume Button

struct VolumeButton: View {
    let isPlus: Bool
    let action: () -> Void

    @State private var isPressed = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: isPressed
                            ? [Color(.systemGray4), Color(.systemGray5)]
                            : [Color(.systemGray5), Color(.systemGray6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 60, height: 44)
                .shadow(
                    color: .black.opacity(isPressed ? 0.1 : 0.2),
                    radius: isPressed ? 1 : 3,
                    y: isPressed ? 0 : 2
                )

            Image(systemName: isPlus ? "plus" : "minus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        SharedHaptics.impactLight()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    action()
                }
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 30) {
            RemoteButton(icon: "house.fill", label: "Home") {
                print("Home pressed")
            }

            HStack(spacing: 20) {
                VolumeButton(isPlus: false) { print("-") }
                VolumeButton(isPlus: true) { print("+") }
            }

            HStack(spacing: 20) {
                IconButton(icon: "mic.fill") { print("Mic") }
                IconButton(icon: "keyboard") { print("Keyboard") }
            }
        }
    }
}
