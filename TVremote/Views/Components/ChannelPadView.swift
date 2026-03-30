//
//  ChannelPadView.swift
//  TVremote
//
//  Numeric channel entry overlay
//

import SwiftUI

struct ChannelPadOverlay: View {
    @Binding var isPresented: Bool
    let onDigit: (Int) -> Void

    private let rows: [[Int?]] = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
        [nil, 0, nil]
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Channel Pad")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Tap a number to send it to the TV")
                            .font(.subheadline)
                            .foregroundStyle(Color(.systemGray))
                    }

                    Spacer()

                    Button("Done") {
                        isPresented = false
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                }

                Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, digit in
                                if let digit {
                                    ChannelDigitButton(digit: digit) {
                                        onDigit(digit)
                                    }
                                } else {
                                    Color.clear
                                        .frame(width: 74, height: 74)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ChannelDigitButton: View {
    let digit: Int
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text("\(digit)")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 74, height: 74)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isPressed
                                    ? [Color(.systemGray4), Color(.systemGray5)]
                                    : [Color(.systemGray5), Color(.systemGray6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(
                    color: .black.opacity(isPressed ? 0.12 : 0.24),
                    radius: isPressed ? 2 : 6,
                    y: isPressed ? 1 : 3
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        SharedHaptics.impactMedium()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .accessibilityLabel("Channel \(digit)")
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ChannelPadOverlay(isPresented: .constant(true)) { digit in
            print("Channel digit: \(digit)")
        }
    }
}
