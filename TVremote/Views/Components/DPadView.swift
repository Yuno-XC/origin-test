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

    enum Direction {
        case up, down, left, right
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let ringSize = min(geo.size.width, geo.size.height) * 0.94
            let centerDiameter = ringSize * (80.0 / 240.0)
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
                            endRadius: ringSize / 2
                        )
                    )
                    .frame(width: ringSize, height: ringSize)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                // Direction indicators
                DirectionIndicators(
                    size: ringSize,
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
                    .frame(width: centerDiameter, height: centerDiameter)
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
            .frame(width: geo.size.width, height: geo.size.height)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChange(value, ringSize: ringSize, centerDiameter: centerDiameter)
                    }
                    .onEnded { value in
                        handleDragEnd(value, ringSize: ringSize, centerDiameter: centerDiameter)
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Gesture Handling

    private func handleDragChange(_ value: DragGesture.Value, ringSize: CGFloat, centerDiameter: CGFloat) {
        let location = value.location
        let center = CGPoint(x: ringSize / 2, y: ringSize / 2)
        let distance = hypot(location.x - center.x, location.y - center.y)

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            // Check if in center zone
            if distance < centerDiameter / 2 {
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
    }

    private func handleDragEnd(_ value: DragGesture.Value, ringSize: CGFloat, centerDiameter: CGFloat) {
        let translation = value.translation
        let swipeThreshold = max(ringSize * 0.12, 20)

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
            SharedHaptics.impactMedium()
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
        SharedHaptics.impactMedium()

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
            .animation(nil, value: isActive)
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
