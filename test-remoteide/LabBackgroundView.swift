//
//  LabBackgroundView.swift
//  test-remoteide
//

import SwiftUI

struct LabBackgroundView: View {
    var kind: LabBackgroundKind

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let longSide = max(w, h)
            switch kind {
            case .aurora:
                LinearGradient(
                    colors: [
                        .purple.opacity(0.85),
                        .blue.opacity(0.75),
                        .cyan.opacity(0.7),
                        .mint.opacity(0.65),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    RadialGradient(
                        colors: [.pink.opacity(0.45), .clear],
                        center: .init(x: 0.15, y: 0.2),
                        startRadius: 0,
                        endRadius: longSide * 0.55
                    )
                }
            case .mesh:
                Canvas { context, size in
                    let step = max(size.width, size.height) * 0.08
                    for x in stride(from: CGFloat(0), through: size.width, by: step) {
                        for y in stride(from: CGFloat(0), through: size.height, by: step) {
                            let rect = CGRect(x: x, y: y, width: step * 0.92, height: step * 0.92)
                            let hue = Double((x + y) / (size.width + size.height))
                            context.fill(
                                Path(roundedRect: rect, cornerRadius: step * 0.12),
                                with: .color(Color(hue: hue, saturation: 0.55, brightness: 0.92))
                            )
                        }
                    }
                }
            case .stripes:
                Canvas { context, size in
                    let stripe = size.width * 0.07
                    var x: CGFloat = 0
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
                .background {
                    LinearGradient(
                        colors: [.orange, .red, .indigo],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}
