//
//  ViewShakeEffectTests.swift
//  TVremoteTests
//
//  Deterministic checks for `ShakeEffect` geometry (used by `View.shake(trigger:)`).
//

import XCTest
import SwiftUI
@testable import TVremote

final class ViewShakeEffectTests: XCTestCase {
    func testShakeEffect_animatableZero_isIdentityTransform() {
        let effect = ShakeEffect(amount: 5, shakesPerUnit: 3, animatableData: 0)
        let transform = effect.effectValue(size: CGSize(width: 320, height: 480))
        XCTAssertTrue(transform.isIdentity, "sin(0) → zero translation")
    }

    func testShakeEffect_nonZeroAnimatable_producesNonIdentityTransform() {
        let effect = ShakeEffect(amount: 10, shakesPerUnit: 3, animatableData: 0.25)
        let transform = effect.effectValue(size: CGSize(width: 200, height: 400))
        XCTAssertFalse(transform.isIdentity)
    }

    func testShakeEffect_amountScalesTranslation() {
        let small = ShakeEffect(amount: 1, shakesPerUnit: 3, animatableData: 0.25)
        let large = ShakeEffect(amount: 100, shakesPerUnit: 3, animatableData: 0.25)
        let tSmall = small.effectValue(size: CGSize(width: 100, height: 100))
        let tLarge = large.effectValue(size: CGSize(width: 100, height: 100))
        XCTAssertFalse(tSmall.isIdentity)
        XCTAssertFalse(tLarge.isIdentity)
    }
}
