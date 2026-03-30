//
//  LiquidGlassLabStateTests.swift
//  test-remoteide
//

import XCTest
import SwiftUI
@testable import test_remoteide

final class LiquidGlassLabStateTests: XCTestCase {
    var sut: LiquidGlassLabState!

    override func setUp() {
        super.setUp()
        sut = LiquidGlassLabState()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertEqual(sut.baseKind, .regular)
        XCTAssertFalse(sut.useTint)
        XCTAssertEqual(sut.tintColor, .blue)
        XCTAssertTrue(sut.interactiveOn)
        XCTAssertEqual(sut.shapeKind, .default)
        XCTAssertEqual(sut.cornerRadiusFraction, 0.18)
        XCTAssertFalse(sut.useCustomContainerSpacing)
        XCTAssertEqual(sut.containerSpacingFraction, 0.04)
        XCTAssertEqual(sut.labBackground, .aurora)
        XCTAssertEqual(sut.appearanceChoice, .system)
        XCTAssertEqual(sut.transitionKind, .identity)
        XCTAssertFalse(sut.unionDemoEnabled)
        XCTAssertEqual(sut.sampleCount, 2)
        XCTAssertTrue(sut.showLabels)
        XCTAssertEqual(sut.previewLayoutChoice, .adaptive)
        XCTAssertFalse(sut.showEffectIDs)
        XCTAssertFalse(sut.showDebugOverlay)
        XCTAssertEqual(sut.backgroundAnimationSpeed, 1.0)
        XCTAssertFalse(sut.backgroundPaused)
        XCTAssertTrue(sut.customSnapshots.isEmpty)
    }

    // MARK: - Snapshot Tests

    func testMakeSnapshot() {
        sut.baseKind = .clear
        sut.useTint = true
        sut.tintColor = .red
        sut.interactiveOn = false
        sut.shapeKind = .capsule
        sut.cornerRadiusFraction = 0.25
        sut.useCustomContainerSpacing = true
        sut.containerSpacingFraction = 0.06
        sut.labBackground = .nebula
        sut.appearanceChoice = .dark
        sut.transitionKind = .materialize
        sut.unionDemoEnabled = true
        sut.sampleCount = 3
        sut.showLabels = false
        sut.previewLayoutChoice = .horizontal
        sut.showEffectIDs = true
        sut.backgroundAnimationSpeed = 0.8
        sut.backgroundPaused = true

        let snapshot = sut.makeSnapshot()

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

    func testApplySnapshot() {
        let snapshot = LabSnapshot(
            baseKind: .identity,
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
            showEffectIDs: false,
            backgroundAnimationSpeed: 1.5,
            backgroundPaused: true
        )

        sut.applySnapshot(snapshot)

        XCTAssertEqual(sut.baseKind, .identity)
        XCTAssertTrue(sut.useTint)
        XCTAssertEqual(sut.tintColor, .green)
        XCTAssertFalse(sut.interactiveOn)
        XCTAssertEqual(sut.shapeKind, .circle)
        XCTAssertEqual(sut.cornerRadiusFraction, 0.3)
        XCTAssertTrue(sut.useCustomContainerSpacing)
        XCTAssertEqual(sut.containerSpacingFraction, 0.08)
        XCTAssertEqual(sut.labBackground, .mesh)
        XCTAssertEqual(sut.appearanceChoice, .light)
        XCTAssertEqual(sut.transitionKind, .matchedGeometry)
        XCTAssertTrue(sut.unionDemoEnabled)
        XCTAssertEqual(sut.sampleCount, 4)
        XCTAssertFalse(sut.showLabels)
        XCTAssertEqual(sut.previewLayoutChoice, .vertical)
        XCTAssertFalse(sut.showEffectIDs)
        XCTAssertEqual(sut.backgroundAnimationSpeed, 1.5)
        XCTAssertTrue(sut.backgroundPaused)
    }

    func testSnapshotRoundTrip() {
        sut.baseKind = .clear
        sut.useTint = true
        sut.tintColor = .orange
        let originalSnapshot = sut.makeSnapshot()

        // Modify state
        sut.baseKind = .identity
        sut.useTint = false
        sut.tintColor = .purple

        // Apply original snapshot
        sut.applySnapshot(originalSnapshot)

        XCTAssertEqual(sut.baseKind, .clear)
        XCTAssertTrue(sut.useTint)
        XCTAssertEqual(sut.tintColor, .orange)
    }

    // MARK: - Reset Tests

    func testReset() {
        sut.baseKind = .clear
        sut.useTint = true
        sut.tintColor = .red
        sut.interactiveOn = false
        sut.shapeKind = .capsule
        sut.cornerRadiusFraction = 0.25
        sut.useCustomContainerSpacing = true
        sut.containerSpacingFraction = 0.06
        sut.labBackground = .nebula
        sut.appearanceChoice = .dark
        sut.transitionKind = .materialize
        sut.unionDemoEnabled = true
        sut.sampleCount = 3
        sut.showLabels = false
        sut.previewLayoutChoice = .horizontal
        sut.showEffectIDs = true
        sut.showDebugOverlay = true
        sut.backgroundAnimationSpeed = 0.8
        sut.backgroundPaused = true

        sut.reset()

        XCTAssertEqual(sut.baseKind, .regular)
        XCTAssertFalse(sut.useTint)
        XCTAssertEqual(sut.tintColor, .blue)
        XCTAssertTrue(sut.interactiveOn)
        XCTAssertEqual(sut.shapeKind, .default)
        XCTAssertEqual(sut.cornerRadiusFraction, 0.18)
        XCTAssertFalse(sut.useCustomContainerSpacing)
        XCTAssertEqual(sut.containerSpacingFraction, 0.04)
        XCTAssertEqual(sut.labBackground, .aurora)
        XCTAssertEqual(sut.appearanceChoice, .system)
        XCTAssertEqual(sut.transitionKind, .identity)
        XCTAssertFalse(sut.unionDemoEnabled)
        XCTAssertEqual(sut.sampleCount, 2)
        XCTAssertTrue(sut.showLabels)
        XCTAssertEqual(sut.previewLayoutChoice, .adaptive)
        XCTAssertFalse(sut.showEffectIDs)
        XCTAssertFalse(sut.showDebugOverlay)
        XCTAssertEqual(sut.backgroundAnimationSpeed, 1.0)
        XCTAssertFalse(sut.backgroundPaused)
    }

    func testResetBackgroundMotion() {
        sut.backgroundAnimationSpeed = 0.5
        sut.backgroundPaused = true

        sut.resetBackgroundMotion()

        XCTAssertEqual(sut.backgroundAnimationSpeed, 1.0)
        XCTAssertFalse(sut.backgroundPaused)
    }

    // MARK: - Randomize Tests

    func testRandomize() {
        sut.randomize()

        // After randomization, values should be set and within expected ranges
        XCTAssertTrue(GlassBaseKind.allCases.contains(sut.baseKind))
        XCTAssertTrue(GlassShapeKind.allCases.contains(sut.shapeKind))
        XCTAssertTrue(LabBackgroundKind.allCases.contains(sut.labBackground))
        XCTAssertTrue(AppearanceChoice.allCases.contains(sut.appearanceChoice))
        XCTAssertTrue(GlassTransitionKind.allCases.contains(sut.transitionKind))
        XCTAssertTrue(PreviewLayoutChoice.allCases.contains(sut.previewLayoutChoice))
        XCTAssert(sut.cornerRadiusFraction >= 0.08 && sut.cornerRadiusFraction <= 0.38)
        XCTAssert(sut.containerSpacingFraction >= 0 && sut.containerSpacingFraction <= 0.16)
        XCTAssert(sut.sampleCount >= 2 && sut.sampleCount <= 4)
        XCTAssert(sut.backgroundAnimationSpeed >= 0.2 && sut.backgroundAnimationSpeed <= 1.9)
    }

    // MARK: - Preset Tests

    func testApplyFrostedPreset() {
        sut.applyPreset(.frosted)

        XCTAssertEqual(sut.baseKind, .regular)
        XCTAssertTrue(sut.useTint)
        XCTAssertTrue(sut.interactiveOn)
        XCTAssertEqual(sut.shapeKind, .roundedRectangle)
        XCTAssertEqual(sut.cornerRadiusFraction, 0.2)
        XCTAssertTrue(sut.useCustomContainerSpacing)
        XCTAssertEqual(sut.containerSpacingFraction, 0.05)
        XCTAssertEqual(sut.transitionKind, .materialize)
        XCTAssertFalse(sut.unionDemoEnabled)
        XCTAssertEqual(sut.sampleCount, 3)
        XCTAssertTrue(sut.showLabels)
        XCTAssertEqual(sut.previewLayoutChoice, .adaptive)
        XCTAssertEqual(sut.labBackground, .aurora)
        XCTAssertEqual(sut.appearanceChoice, .dark)
        XCTAssertFalse(sut.showEffectIDs)
        XCTAssertEqual(sut.backgroundAnimationSpeed, 0.95)
        XCTAssertFalse(sut.backgroundPaused)
    }

    func testApplyNeonPreset() {
        sut.applyPreset(.neon)

        XCTAssertEqual(sut.baseKind, .clear)
        XCTAssertTrue(sut.useTint)
        XCTAssertTrue(sut.interactiveOn)
        XCTAssertEqual(sut.shapeKind, .capsule)
        XCTAssertTrue(sut.useCustomContainerSpacing)
        XCTAssertEqual(sut.containerSpacingFraction, 0.07)
        XCTAssertEqual(sut.transitionKind, .matchedGeometry)
        XCTAssertTrue(sut.unionDemoEnabled)
        XCTAssertEqual(sut.sampleCount, 4)
        XCTAssertFalse(sut.showLabels)
        XCTAssertEqual(sut.previewLayoutChoice, .horizontal)
        XCTAssertEqual(sut.labBackground, .nebula)
        XCTAssertEqual(sut.appearanceChoice, .dark)
        XCTAssertFalse(sut.showEffectIDs)
        XCTAssertEqual(sut.backgroundAnimationSpeed, 1.45)
        XCTAssertFalse(sut.backgroundPaused)
    }

    func testApplyMinimalPreset() {
        sut.applyPreset(.minimal)

        XCTAssertEqual(sut.baseKind, .identity)
        XCTAssertFalse(sut.useTint)
        XCTAssertFalse(sut.interactiveOn)
        XCTAssertEqual(sut.shapeKind, .default)
        XCTAssertFalse(sut.useCustomContainerSpacing)
        XCTAssertEqual(sut.transitionKind, .identity)
        XCTAssertFalse(sut.unionDemoEnabled)
        XCTAssertEqual(sut.sampleCount, 2)
        XCTAssertTrue(sut.showLabels)
        XCTAssertEqual(sut.previewLayoutChoice, .vertical)
        XCTAssertEqual(sut.labBackground, .polarGrid)
        XCTAssertEqual(sut.appearanceChoice, .light)
        XCTAssertTrue(sut.showEffectIDs)
        XCTAssertEqual(sut.backgroundAnimationSpeed, 0.35)
        XCTAssertTrue(sut.backgroundPaused)
    }

    // MARK: - Container Spacing Tests

    func testContainerSpacingWithoutCustomSpacing() {
        sut.useCustomContainerSpacing = false
        sut.containerSpacingFraction = 0.05

        let spacing = sut.containerSpacing(forMinSide: 100)

        XCTAssertNil(spacing)
    }

    func testContainerSpacingWithCustomSpacing() {
        sut.useCustomContainerSpacing = true
        sut.containerSpacingFraction = 0.1

        let spacing = sut.containerSpacing(forMinSide: 100)

        XCTAssertEqual(spacing, 10.0)
    }

    func testContainerSpacingClipsToZero() {
        sut.useCustomContainerSpacing = true
        sut.containerSpacingFraction = 0.2

        let spacing = sut.containerSpacing(forMinSide: 10)

        XCTAssertGreaterThanOrEqual(spacing!, 0)
    }

    func testContainerSpacingWithZeroMinSide() {
        sut.useCustomContainerSpacing = true
        sut.containerSpacingFraction = 0.5

        let spacing = sut.containerSpacing(forMinSide: 0)

        XCTAssertEqual(spacing, 0.0)
    }

    // MARK: - Glass Resolution Tests

    func testResolvedGlassWithoutTint() {
        sut.baseKind = .regular
        sut.useTint = false
        sut.interactiveOn = true

        let glass = sut.resolvedGlass()

        // We can't directly compare Glass objects, but verify the method runs without error
        XCTAssertNotNil(glass)
    }

    func testResolvedGlassWithTint() {
        sut.baseKind = .clear
        sut.useTint = true
        sut.tintColor = .red
        sut.interactiveOn = false

        let glass = sut.resolvedGlass()

        XCTAssertNotNil(glass)
    }

    func testResolvedGlassWithAllBaseKinds() {
        for baseKind in GlassBaseKind.allCases {
            sut.baseKind = baseKind
            let glass = sut.resolvedGlass()
            XCTAssertNotNil(glass)
        }
    }

    // MARK: - Edge Cases Tests

    func testExtremeCornberRadiusFraction() {
        sut.cornerRadiusFraction = 0.0
        var snapshot = sut.makeSnapshot()
        XCTAssertEqual(snapshot.cornerRadiusFraction, 0.0)

        sut.cornerRadiusFraction = 1.0
        snapshot = sut.makeSnapshot()
        XCTAssertEqual(snapshot.cornerRadiusFraction, 1.0)
    }

    func testExtremeContainerSpacingFraction() {
        sut.containerSpacingFraction = 0.0
        var snapshot = sut.makeSnapshot()
        XCTAssertEqual(snapshot.containerSpacingFraction, 0.0)

        sut.containerSpacingFraction = 1.0
        snapshot = sut.makeSnapshot()
        XCTAssertEqual(snapshot.containerSpacingFraction, 1.0)
    }

    func testExtremeBackgroundAnimationSpeed() {
        sut.backgroundAnimationSpeed = 0.0
        var snapshot = sut.makeSnapshot()
        XCTAssertEqual(snapshot.backgroundAnimationSpeed, 0.0)

        sut.backgroundAnimationSpeed = 10.0
        snapshot = sut.makeSnapshot()
        XCTAssertEqual(snapshot.backgroundAnimationSpeed, 10.0)
    }

    func testExtremeSampleCount() {
        sut.sampleCount = 1
        var snapshot = sut.makeSnapshot()
        XCTAssertEqual(snapshot.sampleCount, 1)

        sut.sampleCount = 100
        snapshot = sut.makeSnapshot()
        XCTAssertEqual(snapshot.sampleCount, 100)
    }

    func testContainerSpacingCalculation() {
        sut.useCustomContainerSpacing = true
        sut.containerSpacingFraction = 0.05

        let spacing300 = sut.containerSpacing(forMinSide: 300)
        let spacing150 = sut.containerSpacing(forMinSide: 150)

        XCTAssertEqual(spacing300, 15.0)
        XCTAssertEqual(spacing150, 7.5)
    }
}
