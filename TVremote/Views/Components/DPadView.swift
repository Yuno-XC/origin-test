//
//  DPadView.swift
//  TVremote
//
//  Premium D-Pad navigation control with swipe and tap support
//

import SwiftUI

struct DPadView: View {
    // MARK: - Actions

    let onUp: () -> Void
    let onDown: () -> Void
    let onLeft: () -> Void
    let onRight: () -> Void
    let onCenter: () -> Void

    // MARK: - State

    @State private var activeDirection: Direction?
    @State private var centerPressed = false
    @State private var dragOffset: CGSize = .zero

    private let size: CGFloat = 240
    private let centerSize: CGFloat = 80
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    enum Direction {
        case up, down, left, right
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Outer ring with gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(.systemGray5),
                            Color(.systemGray6)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

            // Direction indicators
            DirectionIndicators(
                size: size,
                activeDirection: activeDirection
            )

            // Center button
            Circle()
                .fill(
                    LinearGradient(
                        colors: centerPressed
                            ? [Color(.systemGray3), Color(.systemGray4)]
                            : [Color(.systemGray4), Color(.systemGray5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: centerSize, height: centerSize)
                .shadow(
                    color: .black.opacity(centerPressed ? 0.1 : 0.2),
                    radius: centerPressed ? 2 : 5,
                    y: centerPressed ? 1 : 3
                )
                .scaleEffect(centerPressed ? 0.95 : 1.0)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChange(value)
                }
                .onEnded { value in
                    handleDragEnd(value)
                }
        )
        .onAppear {
            haptic.prepare()
        }
    }

    // MARK: - Gesture Handling

    private func handleDragChange(_ value: DragGesture.Value) {
        let location = value.location
        let center = CGPoint(x: size / 2, y: size / 2)
        let distance = hypot(location.x - center.x, location.y - center.y)

        // Check if in center zone
        if distance < centerSize / 2 {
            if !centerPressed {
                centerPressed = true
                activeDirection = nil
            }
            return
        }

        centerPressed = false

        // Determine direction
        let angle = atan2(location.y - center.y, location.x - center.x)
        let direction = directionFromAngle(angle)

        if direction != activeDirection {
            activeDirection = direction
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        let location = value.location
        let center = CGPoint(x: size / 2, y: size / 2)
        let distance = hypot(location.x - center.x, location.y - center.y)

        // Check for swipe
        let translation = value.translation
        let swipeThreshold: CGFloat = 30

        if abs(translation.width) > swipeThreshold || abs(translation.height) > swipeThreshold {
            // Swipe gesture
            if abs(translation.width) > abs(translation.height) {
                if translation.width > 0 {
                    triggerDirection(.right)
                } else {
                    triggerDirection(.left)
                }
            } else {
                if translation.height > 0 {
                    triggerDirection(.down)
                } else {
                    triggerDirection(.up)
                }
            }
        } else if centerPressed {
            // Center tap
            haptic.impactOccurred()
            onCenter()
        } else if let direction = activeDirection {
            // Direction tap
            triggerDirection(direction)
        }

        // Reset state
        withAnimation(.easeOut(duration: 0.15)) {
            activeDirection = nil
            centerPressed = false
        }
    }

    private func triggerDirection(_ direction: Direction) {
        haptic.impactOccurred()

        switch direction {
        case .up: onUp()
        case .down: onDown()
        case .left: onLeft()
        case .right: onRight()
        }
    }

    private func directionFromAngle(_ angle: CGFloat) -> Direction {
        let degrees = angle * 180 / .pi

        if degrees > -45 && degrees <= 45 {
            return .right
        } else if degrees > 45 && degrees <= 135 {
            return .down
        } else if degrees > -135 && degrees <= -45 {
            return .up
        } else {
            return .left
        }
    }
}

// MARK: - Direction Indicators

struct DirectionIndicators: View {
    let size: CGFloat
    let activeDirection: DPadView.Direction?

    var body: some View {
        ZStack {
            // Up arrow
            DirectionArrow(
                direction: .up,
                isActive: activeDirection == .up
            )
            .offset(y: -size / 3.5)

            // Down arrow
            DirectionArrow(
                direction: .down,
                isActive: activeDirection == .down
            )
            .offset(y: size / 3.5)

            // Left arrow
            DirectionArrow(
                direction: .left,
                isActive: activeDirection == .left
            )
            .offset(x: -size / 3.5)

            // Right arrow
            DirectionArrow(
                direction: .right,
                isActive: activeDirection == .right
            )
            .offset(x: size / 3.5)
        }
    }
}

struct DirectionArrow: View {
    let direction: DPadView.Direction
    let isActive: Bool

    var body: some View {
        Image(systemName: "chevron.\(directionName)")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(isActive ? .white : Color(.systemGray2))
            .scaleEffect(isActive ? 1.2 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isActive)
    }

    private var directionName: String {
        switch direction {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        DPadView(
            onUp: { print("Up") },
            onDown: { print("Down") },
            onLeft: { print("Left") },
            onRight: { print("Right") },
            onCenter: { print("Center") }
        )
    }
}
