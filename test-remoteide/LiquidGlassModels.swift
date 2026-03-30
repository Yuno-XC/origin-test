//
//  LiquidGlassModels.swift
//  test-remoteide
//

import SwiftUI

enum GlassBaseKind: String, CaseIterable, Identifiable {
    case regular
    case clear
    case identity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regular: "Regular"
        case .clear: "Clear"
        case .identity: "Identity"
        }
    }

    var glass: Glass {
        switch self {
        case .regular: .regular
        case .clear: .clear
        case .identity: .identity
        }
    }
}

enum GlassShapeKind: String, CaseIterable, Identifiable {
    case `default`
    case capsule
    case circle
    case roundedRectangle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default: "Default"
        case .capsule: "Capsule"
        case .circle: "Circle"
        case .roundedRectangle: "Rounded rect"
        }
    }
}

enum GlassTransitionKind: String, CaseIterable, Identifiable {
    case identity
    case matchedGeometry
    case materialize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .identity: "Identity"
        case .matchedGeometry: "Matched geometry"
        case .materialize: "Materialize"
        }
    }

    var transition: GlassEffectTransition {
        switch self {
        case .identity: .identity
        case .matchedGeometry: .matchedGeometry
        case .materialize: .materialize
        }
    }
}

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum PreviewLayoutChoice: String, CaseIterable, Identifiable {
    case adaptive
    case horizontal
    case vertical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adaptive: "Adaptive"
        case .horizontal: "Horizontal"
        case .vertical: "Vertical"
        }
    }
}

enum LabBackgroundKind: String, CaseIterable, Identifiable {
    case aurora
    case mesh
    case stripes
    case nebula
    case polarGrid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aurora: "Aurora glow"
        case .mesh: "Mesh colors"
        case .stripes: "Stripes"
        case .nebula: "Nebula pulse"
        case .polarGrid: "Polar grid"
        }
    }
}

enum LabPreset: String, CaseIterable, Identifiable {
    case frosted
    case neon
    case minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frosted: "Frosted"
        case .neon: "Neon"
        case .minimal: "Minimal"
        }
    }
}
