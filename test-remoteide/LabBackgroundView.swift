//
//  LabBackgroundView.swift
//  test-remoteide
//

import SwiftUI

struct LabBackgroundView: View {
    var kind: LabBackgroundKind
    var animationSpeed: Double = 1.0
    var paused: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let longSide = max(w, h)
                let animatedTime = timeline.date.timeIntervalSinceReferenceDate
                let speed = max(animationSpeed, 0)
                let t = (reduceMotion || paused) ? 0 : animatedTime * speed

                switch kind {
                case .aurora:
                    ZStack {
                        Color.black.opacity(0.94)
                        Circle()
                            .fill(.purple.opacity(0.26))
                            .frame(width: longSide * 0.75, height: longSide * 0.75)
                            .offset(
                                x: -w * 0.22 + cos(t * 0.27) * w * 0.025,
                                y: -h * 0.2 + sin(t * 0.21) * h * 0.02
                            )
                            .blur(radius: longSide * 0.1)
                        Circle()
                            .fill(.cyan.opacity(0.24))
                            .frame(width: longSide * 0.7, height: longSide * 0.7)
                            .offset(
                                x: w * 0.24 + sin(t * 0.24) * w * 0.02,
                                y: h * 0.08 + cos(t * 0.19) * h * 0.025
                            )
                            .blur(radius: longSide * 0.11)
                        Circle()
                            .fill(.mint.opacity(0.2))
                            .frame(width: longSide * 0.62, height: longSide * 0.62)
                            .offset(
                                x: sin(t * 0.17) * w * 0.03,
                                y: h * 0.25 + cos(t * 0.23) * h * 0.02
                            )
                            .blur(radius: longSide * 0.1)
                    }
                case .mesh:
                    Canvas { context, size in
                        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.95)))
                        let step = max(size.width, size.height) * 0.08
                        for x in stride(from: CGFloat(0), through: size.width, by: step) {
                            for y in stride(from: CGFloat(0), through: size.height, by: step) {
                                let rect = CGRect(x: x, y: y, width: step * 0.92, height: step * 0.92)
                                let drift = (sin((x + y) * 0.01 + t * 0.35) + 1) * 0.5
                                let hue = Double((x + y) / max(size.width + size.height, 1))
                                context.fill(
                                    Path(roundedRect: rect, cornerRadius: step * 0.12),
                                    with: .color(Color(hue: hue + drift * 0.08, saturation: 0.55, brightness: 0.92))
                                )
                            }
                        }
                    }
                case .stripes:
                    Canvas { context, size in
                        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.indigo.opacity(0.9)))
                        let stripe = size.width * 0.07
                        let phase = CGFloat((sin(t * 0.4) + 1) * 0.5) * stripe
                        var x: CGFloat = -stripe + phase
                        var toggle = false
                        while x < size.width + stripe {
                            let rect = CGRect(x: x, y: 0, width: stripe, height: size.height)
                            context.fill(
                                Path(rect),
                                with: .color((toggle ? Color.white : Color.black).opacity(0.22))
                            )
                            x += stripe
                            toggle.toggle()
                        }
                    }
                case .nebula:
                    ZStack {
                        Color.black.opacity(0.96)
                        Rectangle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .pink.opacity(0.22),
                                        .purple.opacity(0.2),
                                        .blue.opacity(0.12),
                                        .clear
                                    ],
                                    center: UnitPoint(
                                        x: 0.25 + cos(t * 0.13) * 0.1,
                                        y: 0.28 + sin(t * 0.15) * 0.09
                                    ),
                                    startRadius: longSide * 0.02,
                                    endRadius: longSide * 0.9
                                )
                            )
                        Rectangle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .cyan.opacity(0.18),
                                        .indigo.opacity(0.2),
                                        .clear
                                    ],
                                    center: UnitPoint(
                                        x: 0.74 + sin(t * 0.11) * 0.08,
                                        y: 0.62 + cos(t * 0.14) * 0.08
                                    ),
                                    startRadius: longSide * 0.02,
                                    endRadius: longSide * 0.85
                                )
                            )
                        Canvas { context, size in
                            let star = max(min(size.width, size.height) * 0.0022, 1)
                            let count = Int(max(size.width, size.height) * 0.1)
                            for idx in 0..<count {
                                let seed = Double(idx + 1)
                                let x = CGFloat((sin(seed * 12.9898) * 43_758.5453).truncatingRemainder(dividingBy: 1)).magnitude * size.width
                                let y = CGFloat((sin(seed * 78.233) * 12_345.6789).truncatingRemainder(dividingBy: 1)).magnitude * size.height
                                let twinkle = 0.45 + 0.55 * (sin(t * 0.9 + seed) + 1) * 0.5
                                let rect = CGRect(x: x, y: y, width: star, height: star)
                                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(twinkle)))
                            }
                        }
                        .blur(radius: longSide * 0.0015)
                    }
                case .polarGrid:
                    Canvas { context, size in
                        let base = Path(CGRect(origin: .zero, size: size))
                        context.fill(base, with: .color(.black.opacity(0.95)))

                        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                        let ringGap = max(min(size.width, size.height) * 0.08, 1)
                        let maxRadius = max(size.width, size.height) * 0.8

                        var radius: CGFloat = ringGap
                        while radius <= maxRadius {
                            let alpha = max(0.08, 0.28 - (radius / maxRadius) * 0.18)
                            var ring = Path()
                            ring.addEllipse(in: CGRect(
                                x: center.x - radius,
                                y: center.y - radius,
                                width: radius * 2,
                                height: radius * 2
                            ))
                            context.stroke(ring, with: .color(.cyan.opacity(alpha)), lineWidth: max(ringGap * 0.03, 0.5))
                            radius += ringGap
                        }

                        let spokeCount = 24
                        let angleOffset = t * 0.08
                        for i in 0..<spokeCount {
                            let angle = CGFloat(Double(i) / Double(spokeCount) * .pi * 2 + angleOffset)
                            let end = CGPoint(
                                x: center.x + cos(angle) * maxRadius,
                                y: center.y + sin(angle) * maxRadius
                            )
                            var spoke = Path()
                            spoke.move(to: center)
                            spoke.addLine(to: end)
                            context.stroke(spoke, with: .color(.mint.opacity(0.2)), lineWidth: max(ringGap * 0.02, 0.4))
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
