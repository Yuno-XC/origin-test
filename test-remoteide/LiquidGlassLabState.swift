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
    var sampleCount = 2
    var showLabels = true
    var previewLayoutChoice: PreviewLayoutChoice = .adaptive
    var showEffectIDs = false
    var showDebugOverlay = false
    var backgroundAnimationSpeed: Double = 1.0
    var backgroundPaused = false

    var customSnapshots: [NamedLabSnapshot] = []

    func resolvedGlass() -> Glass {
        var g = baseKind.glass
        if useTint {
            g = g.tint(tintColor)
        }
        g = g.interactive(interactiveOn)
        return g
    }

    func makeSnapshot() -> LabSnapshot {
        LabSnapshot(
            baseKind: baseKind,
            useTint: useTint,
            tintColor: tintColor,
            interactiveOn: interactiveOn,
            shapeKind: shapeKind,
            cornerRadiusFraction: cornerRadiusFraction,
            useCustomContainerSpacing: useCustomContainerSpacing,
            containerSpacingFraction: containerSpacingFraction,
            labBackground: labBackground,
            appearanceChoice: appearanceChoice,
            transitionKind: transitionKind,
            unionDemoEnabled: unionDemoEnabled,
            sampleCount: sampleCount,
            showLabels: showLabels,
            previewLayoutChoice: previewLayoutChoice,
            showEffectIDs: showEffectIDs,
            backgroundAnimationSpeed: backgroundAnimationSpeed,
            backgroundPaused: backgroundPaused
        )
    }

    func applySnapshot(_ snapshot: LabSnapshot) {
        baseKind = snapshot.baseKind
        useTint = snapshot.useTint
        tintColor = snapshot.tintColor
        interactiveOn = snapshot.interactiveOn
        shapeKind = snapshot.shapeKind
        cornerRadiusFraction = snapshot.cornerRadiusFraction
        useCustomContainerSpacing = snapshot.useCustomContainerSpacing
        containerSpacingFraction = snapshot.containerSpacingFraction
        labBackground = snapshot.labBackground
        appearanceChoice = snapshot.appearanceChoice
        transitionKind = snapshot.transitionKind
        unionDemoEnabled = snapshot.unionDemoEnabled
        sampleCount = snapshot.sampleCount
        showLabels = snapshot.showLabels
        previewLayoutChoice = snapshot.previewLayoutChoice
        showEffectIDs = snapshot.showEffectIDs
        backgroundAnimationSpeed = snapshot.backgroundAnimationSpeed
        backgroundPaused = snapshot.backgroundPaused
    }

    func containerSpacing(forMinSide minSide: CGFloat) -> CGFloat? {
        guard useCustomContainerSpacing else { return nil }
        return max(minSide * containerSpacingFraction, 0)
    }

    func reset() {
        baseKind = .regular
        useTint = false
        tintColor = .blue
        interactiveOn = true
        shapeKind = .default
        cornerRadiusFraction = 0.18
        useCustomContainerSpacing = false
        containerSpacingFraction = 0.04
        labBackground = .aurora
        appearanceChoice = .system
        transitionKind = .identity
        unionDemoEnabled = false
        sampleCount = 2
        showLabels = true
        previewLayoutChoice = .adaptive
        showEffectIDs = false
        showDebugOverlay = false
        backgroundAnimationSpeed = 1.0
        backgroundPaused = false
    }

    func resetBackgroundMotion() {
        backgroundAnimationSpeed = 1.0
        backgroundPaused = false
    }

    func randomize() {
        baseKind = GlassBaseKind.allCases.randomElement() ?? .regular
        useTint = Bool.random()
        if useTint {
            tintColor = Color(
                hue: Double.random(in: 0...1),
                saturation: Double.random(in: 0.3...0.95),
                brightness: Double.random(in: 0.7...1)
            )
        }
        interactiveOn = Bool.random()
        shapeKind = GlassShapeKind.allCases.randomElement() ?? .default
        cornerRadiusFraction = CGFloat.random(in: 0.08...0.38)
        useCustomContainerSpacing = Bool.random()
        containerSpacingFraction = CGFloat.random(in: 0...0.16)
        labBackground = LabBackgroundKind.allCases.randomElement() ?? .aurora
        appearanceChoice = AppearanceChoice.allCases.randomElement() ?? .system
        transitionKind = GlassTransitionKind.allCases.randomElement() ?? .identity
        unionDemoEnabled = Bool.random()
        sampleCount = Int.random(in: 2...4)
        showLabels = Bool.random()
        showEffectIDs = Bool.random()
        previewLayoutChoice = PreviewLayoutChoice.allCases.randomElement() ?? .adaptive
        backgroundAnimationSpeed = Double.random(in: 0.2...1.9)
        backgroundPaused = Bool.random()
    }

    func applyPreset(_ preset: LabPreset) {
        switch preset {
        case .frosted:
            baseKind = .regular
            useTint = true
            tintColor = .cyan.opacity(0.45)
            interactiveOn = true
            shapeKind = .roundedRectangle
            cornerRadiusFraction = 0.2
            useCustomContainerSpacing = true
            containerSpacingFraction = 0.05
            transitionKind = .materialize
            unionDemoEnabled = false
            sampleCount = 3
            showLabels = true
            previewLayoutChoice = .adaptive
            labBackground = .aurora
            appearanceChoice = .dark
            showEffectIDs = false
            backgroundAnimationSpeed = 0.95
            backgroundPaused = false
        case .neon:
            baseKind = .clear
            useTint = true
            tintColor = .pink.opacity(0.6)
            interactiveOn = true
            shapeKind = .capsule
            useCustomContainerSpacing = true
            containerSpacingFraction = 0.07
            transitionKind = .matchedGeometry
            unionDemoEnabled = true
            sampleCount = 4
            showLabels = false
            previewLayoutChoice = .horizontal
            labBackground = .nebula
            appearanceChoice = .dark
            showEffectIDs = false
            backgroundAnimationSpeed = 1.45
            backgroundPaused = false
        case .minimal:
            baseKind = .identity
            useTint = false
            interactiveOn = false
            shapeKind = .default
            useCustomContainerSpacing = false
            transitionKind = .identity
            unionDemoEnabled = false
            sampleCount = 2
            showLabels = true
            previewLayoutChoice = .vertical
            labBackground = .polarGrid
            appearanceChoice = .light
            showEffectIDs = true
            backgroundAnimationSpeed = 0.35
            backgroundPaused = true
        }
    }
}

struct LabSnapshot {
    var baseKind: GlassBaseKind
    var useTint: Bool
    var tintColor: Color
    var interactiveOn: Bool
    var shapeKind: GlassShapeKind
    var cornerRadiusFraction: CGFloat
    var useCustomContainerSpacing: Bool
    var containerSpacingFraction: CGFloat
    var labBackground: LabBackgroundKind
    var appearanceChoice: AppearanceChoice
    var transitionKind: GlassTransitionKind
    var unionDemoEnabled: Bool
    var sampleCount: Int
    var showLabels: Bool
    var previewLayoutChoice: PreviewLayoutChoice
    var showEffectIDs: Bool
    var backgroundAnimationSpeed: Double
    var backgroundPaused: Bool
}

struct NamedLabSnapshot: Identifiable {
    let id: UUID
    var name: String
    var snapshot: LabSnapshot

    init(id: UUID = UUID(), name: String, snapshot: LabSnapshot) {
        self.id = id
        self.name = name
        self.snapshot = snapshot
    }
}
