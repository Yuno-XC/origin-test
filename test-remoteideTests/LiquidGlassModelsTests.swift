//
//  LiquidGlassModelsTests.swift
//  test-remoteide
//

import XCTest
import SwiftUI
@testable import test_remoteide

final class GlassBaseKindTests: XCTestCase {
    func testAllCasesExist() {
        XCTAssertEqual(GlassBaseKind.allCases.count, 3)
        XCTAssert(GlassBaseKind.allCases.contains(.regular))
        XCTAssert(GlassBaseKind.allCases.contains(.clear))
        XCTAssert(GlassBaseKind.allCases.contains(.identity))
    }

    func testRawValues() {
        XCTAssertEqual(GlassBaseKind.regular.rawValue, "regular")
        XCTAssertEqual(GlassBaseKind.clear.rawValue, "clear")
        XCTAssertEqual(GlassBaseKind.identity.rawValue, "identity")
    }

    func testIdentifiable() {
        XCTAssertEqual(GlassBaseKind.regular.id, "regular")
        XCTAssertEqual(GlassBaseKind.clear.id, "clear")
        XCTAssertEqual(GlassBaseKind.identity.id, "identity")
    }

    func testTitles() {
        XCTAssertEqual(GlassBaseKind.regular.title, "Regular")
        XCTAssertEqual(GlassBaseKind.clear.title, "Clear")
        XCTAssertEqual(GlassBaseKind.identity.title, "Identity")
    }

    func testGlassMapping() {
        XCTAssertEqual(GlassBaseKind.regular.glass, .regular)
        XCTAssertEqual(GlassBaseKind.clear.glass, .clear)
        XCTAssertEqual(GlassBaseKind.identity.glass, .identity)
    }

    func testUniqueIDs() {
        let ids = GlassBaseKind.allCases.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}

final class GlassShapeKindTests: XCTestCase {
    func testAllCasesExist() {
        XCTAssertEqual(GlassShapeKind.allCases.count, 4)
        XCTAssert(GlassShapeKind.allCases.contains(.default))
        XCTAssert(GlassShapeKind.allCases.contains(.capsule))
        XCTAssert(GlassShapeKind.allCases.contains(.circle))
        XCTAssert(GlassShapeKind.allCases.contains(.roundedRectangle))
    }

    func testRawValues() {
        XCTAssertEqual(GlassShapeKind.default.rawValue, "default")
        XCTAssertEqual(GlassShapeKind.capsule.rawValue, "capsule")
        XCTAssertEqual(GlassShapeKind.circle.rawValue, "circle")
        XCTAssertEqual(GlassShapeKind.roundedRectangle.rawValue, "roundedRectangle")
    }

    func testIdentifiable() {
        XCTAssertEqual(GlassShapeKind.default.id, "default")
        XCTAssertEqual(GlassShapeKind.capsule.id, "capsule")
        XCTAssertEqual(GlassShapeKind.circle.id, "circle")
        XCTAssertEqual(GlassShapeKind.roundedRectangle.id, "roundedRectangle")
    }

    func testTitles() {
        XCTAssertEqual(GlassShapeKind.default.title, "Default")
        XCTAssertEqual(GlassShapeKind.capsule.title, "Capsule")
        XCTAssertEqual(GlassShapeKind.circle.title, "Circle")
        XCTAssertEqual(GlassShapeKind.roundedRectangle.title, "Rounded rect")
    }

    func testUniqueIDs() {
        let ids = GlassShapeKind.allCases.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}

final class GlassTransitionKindTests: XCTestCase {
    func testAllCasesExist() {
        XCTAssertEqual(GlassTransitionKind.allCases.count, 3)
        XCTAssert(GlassTransitionKind.allCases.contains(.identity))
        XCTAssert(GlassTransitionKind.allCases.contains(.matchedGeometry))
        XCTAssert(GlassTransitionKind.allCases.contains(.materialize))
    }

    func testRawValues() {
        XCTAssertEqual(GlassTransitionKind.identity.rawValue, "identity")
        XCTAssertEqual(GlassTransitionKind.matchedGeometry.rawValue, "matchedGeometry")
        XCTAssertEqual(GlassTransitionKind.materialize.rawValue, "materialize")
    }

    func testIdentifiable() {
        XCTAssertEqual(GlassTransitionKind.identity.id, "identity")
        XCTAssertEqual(GlassTransitionKind.matchedGeometry.id, "matchedGeometry")
        XCTAssertEqual(GlassTransitionKind.materialize.id, "materialize")
    }

    func testTitles() {
        XCTAssertEqual(GlassTransitionKind.identity.title, "Identity")
        XCTAssertEqual(GlassTransitionKind.matchedGeometry.title, "Matched geometry")
        XCTAssertEqual(GlassTransitionKind.materialize.title, "Materialize")
    }

    func testTransitionMapping() {
        XCTAssertEqual(String(describing: GlassTransitionKind.identity.transition), "identity")
        XCTAssertEqual(String(describing: GlassTransitionKind.matchedGeometry.transition), "matchedGeometry")
        XCTAssertEqual(String(describing: GlassTransitionKind.materialize.transition), "materialize")
    }

    func testUniqueIDs() {
        let ids = GlassTransitionKind.allCases.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}

final class AppearanceChoiceTests: XCTestCase {
    func testAllCasesExist() {
        XCTAssertEqual(AppearanceChoice.allCases.count, 3)
        XCTAssert(AppearanceChoice.allCases.contains(.system))
        XCTAssert(AppearanceChoice.allCases.contains(.light))
        XCTAssert(AppearanceChoice.allCases.contains(.dark))
    }

    func testRawValues() {
        XCTAssertEqual(AppearanceChoice.system.rawValue, "system")
        XCTAssertEqual(AppearanceChoice.light.rawValue, "light")
        XCTAssertEqual(AppearanceChoice.dark.rawValue, "dark")
    }

    func testIdentifiable() {
        XCTAssertEqual(AppearanceChoice.system.id, "system")
        XCTAssertEqual(AppearanceChoice.light.id, "light")
        XCTAssertEqual(AppearanceChoice.dark.id, "dark")
    }

    func testColorSchemeMapping() {
        XCTAssertNil(AppearanceChoice.system.colorScheme)
        XCTAssertEqual(AppearanceChoice.light.colorScheme, .light)
        XCTAssertEqual(AppearanceChoice.dark.colorScheme, .dark)
    }

    func testUniqueIDs() {
        let ids = AppearanceChoice.allCases.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}

final class PreviewLayoutChoiceTests: XCTestCase {
    func testAllCasesExist() {
        XCTAssertEqual(PreviewLayoutChoice.allCases.count, 3)
        XCTAssert(PreviewLayoutChoice.allCases.contains(.adaptive))
        XCTAssert(PreviewLayoutChoice.allCases.contains(.horizontal))
        XCTAssert(PreviewLayoutChoice.allCases.contains(.vertical))
    }

    func testRawValues() {
        XCTAssertEqual(PreviewLayoutChoice.adaptive.rawValue, "adaptive")
        XCTAssertEqual(PreviewLayoutChoice.horizontal.rawValue, "horizontal")
        XCTAssertEqual(PreviewLayoutChoice.vertical.rawValue, "vertical")
    }

    func testIdentifiable() {
        XCTAssertEqual(PreviewLayoutChoice.adaptive.id, "adaptive")
        XCTAssertEqual(PreviewLayoutChoice.horizontal.id, "horizontal")
        XCTAssertEqual(PreviewLayoutChoice.vertical.id, "vertical")
    }

    func testTitles() {
        XCTAssertEqual(PreviewLayoutChoice.adaptive.title, "Adaptive")
        XCTAssertEqual(PreviewLayoutChoice.horizontal.title, "Horizontal")
        XCTAssertEqual(PreviewLayoutChoice.vertical.title, "Vertical")
    }

    func testUniqueIDs() {
        let ids = PreviewLayoutChoice.allCases.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}

final class LabBackgroundKindTests: XCTestCase {
    func testAllCasesExist() {
        XCTAssertEqual(LabBackgroundKind.allCases.count, 5)
        XCTAssert(LabBackgroundKind.allCases.contains(.aurora))
        XCTAssert(LabBackgroundKind.allCases.contains(.mesh))
        XCTAssert(LabBackgroundKind.allCases.contains(.stripes))
        XCTAssert(LabBackgroundKind.allCases.contains(.nebula))
        XCTAssert(LabBackgroundKind.allCases.contains(.polarGrid))
    }

    func testRawValues() {
        XCTAssertEqual(LabBackgroundKind.aurora.rawValue, "aurora")
        XCTAssertEqual(LabBackgroundKind.mesh.rawValue, "mesh")
        XCTAssertEqual(LabBackgroundKind.stripes.rawValue, "stripes")
        XCTAssertEqual(LabBackgroundKind.nebula.rawValue, "nebula")
        XCTAssertEqual(LabBackgroundKind.polarGrid.rawValue, "polarGrid")
    }

    func testIdentifiable() {
        XCTAssertEqual(LabBackgroundKind.aurora.id, "aurora")
        XCTAssertEqual(LabBackgroundKind.mesh.id, "mesh")
        XCTAssertEqual(LabBackgroundKind.stripes.id, "stripes")
        XCTAssertEqual(LabBackgroundKind.nebula.id, "nebula")
        XCTAssertEqual(LabBackgroundKind.polarGrid.id, "polarGrid")
    }

    func testTitles() {
        XCTAssertEqual(LabBackgroundKind.aurora.title, "Aurora glow")
        XCTAssertEqual(LabBackgroundKind.mesh.title, "Mesh colors")
        XCTAssertEqual(LabBackgroundKind.stripes.title, "Stripes")
        XCTAssertEqual(LabBackgroundKind.nebula.title, "Nebula pulse")
        XCTAssertEqual(LabBackgroundKind.polarGrid.title, "Polar grid")
    }

    func testUniqueIDs() {
        let ids = LabBackgroundKind.allCases.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}

final class LabPresetTests: XCTestCase {
    func testAllCasesExist() {
        XCTAssertEqual(LabPreset.allCases.count, 3)
        XCTAssert(LabPreset.allCases.contains(.frosted))
        XCTAssert(LabPreset.allCases.contains(.neon))
        XCTAssert(LabPreset.allCases.contains(.minimal))
    }

    func testRawValues() {
        XCTAssertEqual(LabPreset.frosted.rawValue, "frosted")
        XCTAssertEqual(LabPreset.neon.rawValue, "neon")
        XCTAssertEqual(LabPreset.minimal.rawValue, "minimal")
    }

    func testIdentifiable() {
        XCTAssertEqual(LabPreset.frosted.id, "frosted")
        XCTAssertEqual(LabPreset.neon.id, "neon")
        XCTAssertEqual(LabPreset.minimal.id, "minimal")
    }

    func testTitles() {
        XCTAssertEqual(LabPreset.frosted.title, "Frosted")
        XCTAssertEqual(LabPreset.neon.title, "Neon")
        XCTAssertEqual(LabPreset.minimal.title, "Minimal")
    }

    func testUniqueIDs() {
        let ids = LabPreset.allCases.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}

final class LabSnapshotTests: XCTestCase {
    func testSnapshotCreation() {
        let snapshot = LabSnapshot(
            baseKind: .clear,
            useTint: true,
            tintColor: .red,
            interactiveOn: false,
            shapeKind: .capsule,
            cornerRadiusFraction: 0.25,
            useCustomContainerSpacing: true,
            containerSpacingFraction: 0.06,
            labBackground: .nebula,
            appearanceChoice: .dark,
            transitionKind: .materialize,
            unionDemoEnabled: true,
            sampleCount: 3,
            showLabels: false,
            previewLayoutChoice: .horizontal,
            showEffectIDs: true,
            backgroundAnimationSpeed: 0.8,
            backgroundPaused: true
        )

        XCTAssertEqual(snapshot.baseKind, .clear)
        XCTAssertTrue(snapshot.useTint)
        XCTAssertEqual(snapshot.tintColor, .red)
        XCTAssertFalse(snapshot.interactiveOn)
        XCTAssertEqual(snapshot.shapeKind, .capsule)
        XCTAssertEqual(snapshot.cornerRadiusFraction, 0.25)
        XCTAssertTrue(snapshot.useCustomContainerSpacing)
        XCTAssertEqual(snapshot.containerSpacingFraction, 0.06)
        XCTAssertEqual(snapshot.labBackground, .nebula)
        XCTAssertEqual(snapshot.appearanceChoice, .dark)
        XCTAssertEqual(snapshot.transitionKind, .materialize)
        XCTAssertTrue(snapshot.unionDemoEnabled)
        XCTAssertEqual(snapshot.sampleCount, 3)
        XCTAssertFalse(snapshot.showLabels)
        XCTAssertEqual(snapshot.previewLayoutChoice, .horizontal)
        XCTAssertTrue(snapshot.showEffectIDs)
        XCTAssertEqual(snapshot.backgroundAnimationSpeed, 0.8)
        XCTAssertTrue(snapshot.backgroundPaused)
    }
}

final class NamedLabSnapshotTests: XCTestCase {
    func testNamedSnapshotCreationWithDefaultID() {
        let snapshot = LabSnapshot(
            baseKind: .regular,
            useTint: false,
            tintColor: .blue,
            interactiveOn: true,
            shapeKind: .default,
            cornerRadiusFraction: 0.18,
            useCustomContainerSpacing: false,
            containerSpacingFraction: 0.04,
            labBackground: .aurora,
            appearanceChoice: .system,
            transitionKind: .identity,
            unionDemoEnabled: false,
            sampleCount: 2,
            showLabels: true,
            previewLayoutChoice: .adaptive,
            showEffectIDs: false,
            backgroundAnimationSpeed: 1.0,
            backgroundPaused: false
        )

        let namedSnapshot = NamedLabSnapshot(name: "Test", snapshot: snapshot)

        XCTAssertNotNil(namedSnapshot.id)
        XCTAssertEqual(namedSnapshot.name, "Test")
        XCTAssertEqual(namedSnapshot.snapshot.baseKind, .regular)
    }

    func testNamedSnapshotCreationWithCustomID() {
        let customID = UUID()
        let snapshot = LabSnapshot(
            baseKind: .clear,
            useTint: true,
            tintColor: .green,
            interactiveOn: false,
            shapeKind: .circle,
            cornerRadiusFraction: 0.3,
            useCustomContainerSpacing: true,
            containerSpacingFraction: 0.08,
            labBackground: .mesh,
            appearanceChoice: .light,
            transitionKind: .matchedGeometry,
            unionDemoEnabled: true,
            sampleCount: 4,
            showLabels: false,
            previewLayoutChoice: .vertical,
            showEffectIDs: true,
            backgroundAnimationSpeed: 1.5,
            backgroundPaused: true
        )

        let namedSnapshot = NamedLabSnapshot(id: customID, name: "Custom", snapshot: snapshot)

        XCTAssertEqual(namedSnapshot.id, customID)
        XCTAssertEqual(namedSnapshot.name, "Custom")
    }

    func testNamedSnapshotIdentifiable() {
        let id1 = UUID()
        let id2 = UUID()

        let snapshot = LabSnapshot(
            baseKind: .regular,
            useTint: false,
            tintColor: .blue,
            interactiveOn: true,
            shapeKind: .default,
            cornerRadiusFraction: 0.18,
            useCustomContainerSpacing: false,
            containerSpacingFraction: 0.04,
            labBackground: .aurora,
            appearanceChoice: .system,
            transitionKind: .identity,
            unionDemoEnabled: false,
            sampleCount: 2,
            showLabels: true,
            previewLayoutChoice: .adaptive,
            showEffectIDs: false,
            backgroundAnimationSpeed: 1.0,
            backgroundPaused: false
        )

        let snapshot1 = NamedLabSnapshot(id: id1, name: "First", snapshot: snapshot)
        let snapshot2 = NamedLabSnapshot(id: id2, name: "Second", snapshot: snapshot)

        XCTAssertNotEqual(snapshot1.id, snapshot2.id)
    }
}
