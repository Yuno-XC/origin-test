//
//  VolumeControlView.swift
//  TVremote
//
//  Vertical volume slider control
//

import SwiftUI
import Combine

struct VolumeControlView: View {
    let onVolumeUp: () -> Void
    let onVolumeDown: () -> Void
    let onMute: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Volume Up
            VolumeControlButton(icon: "plus") {
                onVolumeUp()
            }

            // Volume icon
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(.systemGray))
                .frame(height: 30)

            // Volume Down
            VolumeControlButton(icon: "minus") {
                onVolumeDown()
            }

            Spacer()
                .frame(height: 8)

            // Mute button
            MuteButton {
                onMute()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

// MARK: - Volume Control Button

struct VolumeControlButton: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false
    @GestureState private var isHolding = false

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    @State private var repeatCount = 0
    // #region agent log
    @State private var timerFireCount = 0
    // #endregion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: isPressed
                            ? [Color(.systemGray4), Color(.systemGray5)]
                            : [Color(.systemGray5), Color(.systemGray6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 48, height: 48)
                .shadow(
                    color: .black.opacity(isPressed ? 0.1 : 0.2),
                    radius: isPressed ? 1 : 3,
                    y: isPressed ? 0 : 2
                )

            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        haptic.impactOccurred()
                        action()
                        repeatCount = 0
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    repeatCount = 0
                }
        )
        .onReceive(timer) { _ in
            // #region agent log
            #if DEBUG
            timerFireCount += 1
            if timerFireCount % 20 == 0 {
                DebugPerfLogger.log(location: "VolumeControlView.swift:onReceive", message: "Timer fire", hypothesisId: "A", data: ["count": "\(timerFireCount)", "isPressed": "\(isPressed)"])
            }
            #endif
            // #endregion
            if isPressed {
                repeatCount += 1
                if repeatCount > 2 { // Start repeating after short delay
                    haptic.impactOccurred()
                    action()
                }
            }
        }
        .onAppear {
            haptic.prepare()
        }
    }
}

// MARK: - Mute Button

struct MuteButton: View {
    let action: () -> Void

    @State private var isPressed = false
    @State private var isMuted = false
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    isMuted
                        ? Color.red.opacity(0.3)
                        : (isPressed ? Color(.systemGray4) : Color(.systemGray5))
                )
                .frame(width: 44, height: 44)

            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.slash")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isMuted ? .red : .white)
        }
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        haptic.impactOccurred()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    isMuted.toggle()
                    action()
                }
        )
        .onAppear {
            haptic.prepare()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VolumeControlView(
            onVolumeUp: { print("Vol +") },
            onVolumeDown: { print("Vol -") },
            onMute: { print("Mute") }
        )
    }
}
