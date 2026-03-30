//
//  MediaControlsView.swift
//  TVremote
//
//  Media playback controls
//

import SwiftUI

struct MediaControlsView: View {
    let onPlayPause: () -> Void
    let onRewind: () -> Void
    let onFastForward: () -> Void
    let onRewindRelease: () -> Void
    let onFastForwardRelease: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Previous
            MediaButton(icon: "backward.end.fill", size: .small) {
                onPrevious()
            }

            Spacer()

            // Rewind
            MediaButton(
                icon: "backward.fill",
                size: .medium,
                onPress: onRewind,
                onRelease: onRewindRelease
            )

            Spacer()

            // Play/Pause
            MediaButton(icon: "playpause.fill", size: .large) {
                onPlayPause()
            }

            Spacer()

            // Fast Forward
            MediaButton(
                icon: "forward.fill",
                size: .medium,
                onPress: onFastForward,
                onRelease: onFastForwardRelease
            )

            Spacer()

            // Next
            MediaButton(icon: "forward.end.fill", size: .small) {
                onNext()
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Media Button

struct MediaButton: View {
    enum Size {
        case small, medium, large

        var dimension: CGFloat {
            switch self {
            case .small: return 44
            case .medium: return 52
            case .large: return 64
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 26
            }
        }
    }

    let icon: String
    let size: Size
    var onTap: (() -> Void)?
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    @State private var isPressed = false
    init(
        icon: String,
        size: Size,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.onTap = action
        self.onPress = nil
        self.onRelease = nil
    }

    init(
        icon: String,
        size: Size,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.onTap = nil
        self.onPress = onPress
        self.onRelease = onRelease
    }

    var body: some View {
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
                .frame(width: size.dimension, height: size.dimension)
                .shadow(
                    color: .black.opacity(isPressed ? 0.1 : 0.25),
                    radius: isPressed ? 2 : 4,
                    y: isPressed ? 1 : 2
                )

            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundColor(.white)
        }
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        SharedHaptics.impactMedium()
                        onPress?()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    if onPress != nil {
                        onRelease?()
                    } else {
                        onTap?()
                    }
                }
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        MediaControlsView(
            onPlayPause: { print("Play/Pause") },
            onRewind: { print("Rewind start") },
            onFastForward: { print("FF start") },
            onRewindRelease: { print("Rewind end") },
            onFastForwardRelease: { print("FF end") },
            onPrevious: { print("Previous") },
            onNext: { print("Next") }
        )
    }
}
