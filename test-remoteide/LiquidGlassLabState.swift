//
//  LiquidGlassLabState.swift
//  test-remoteide
//

import Observation
import SwiftUI

@Observable
@MainActor
final class LiquidGlassLabState {
    var baseKind: GlassBaseKind = .regular
    var useTint = false
    var tintColor: Color = .blue
    var interactiveOn = true
    var shapeKind: GlassShapeKind = .default
    /// Corner radius as a fraction of min(preview width, height), for rounded-rectangle shape only.
    var cornerRadiusFraction: CGFloat = 0.18
    var useCustomContainerSpacing = false
    var containerSpacingFraction: CGFloat = 0.04
    var labBackground: LabBackgroundKind = .aurora
    var appearanceChoice: AppearanceChoice = .system
    var transitionKind: GlassTransitionKind = .identity
    var unionDemoEnabled = false

    func resolvedGlass() -> Glass {
        var g = baseKind.glass
        if useTint {
            g = g.tint(tintColor)
        }
        g = g.interactive(interactiveOn)
        return g
    }

    func containerSpacing(forMinSide minSide: CGFloat) -> CGFloat? {
        guard useCustomContainerSpacing else { return nil }
        return max(minSide * containerSpacingFraction, 0)
    }
}
