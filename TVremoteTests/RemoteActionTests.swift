//
//  RemoteActionTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

final class RemoteActionTests: XCTestCase {
    func testRequiresLongPress_onlyRewindAndFastForward() {
        let longPressCases: [RemoteAction] = [.rewind, .fastForward]
        for action in longPressCases {
            XCTAssertTrue(action.requiresLongPress, "\(action)")
        }

        let samples: [RemoteAction] = [
            .dpadUp,
            .home,
            .playPause,
            .play,
            .pause,
            .stop,
            .volumeUp,
            .channelDigit(4),
            .power,
            .textInput("hi"),
            .deleteCharacter,
            .enter,
            .openApp("https://example.com")
        ]
        for action in samples {
            XCTAssertFalse(action.requiresLongPress, "\(action)")
        }
    }

    func testRemoteActionEquatable_associatedValues() {
        XCTAssertEqual(RemoteAction.textInput("a"), RemoteAction.textInput("a"))
        XCTAssertNotEqual(RemoteAction.textInput("a"), RemoteAction.textInput("b"))
        XCTAssertEqual(RemoteAction.channelDigit(7), RemoteAction.channelDigit(7))
        XCTAssertNotEqual(RemoteAction.channelDigit(7), RemoteAction.channelDigit(8))
        XCTAssertEqual(RemoteAction.openApp("x"), RemoteAction.openApp("x"))
        XCTAssertNotEqual(RemoteAction.openApp("x"), RemoteAction.openApp("y"))
    }

    func testRemoteActionEquatable_allSimpleCases_pairwiseDistinct() {
        let simple: [RemoteAction] = [
            .dpadUp, .dpadDown, .dpadLeft, .dpadRight, .dpadCenter,
            .home, .back, .menu,
            .playPause, .play, .pause, .stop, .next, .previous, .rewind, .fastForward,
            .volumeUp, .volumeDown, .mute,
            .power,
            .deleteCharacter, .enter
        ]
        for i in simple.indices {
            for j in (i + 1)..<simple.count {
                XCTAssertNotEqual(simple[i], simple[j])
            }
        }
    }

    func testKeyPressDirection_casesAreDistinct() {
        XCTAssertNotEqual(KeyPressDirection.short, KeyPressDirection.startLong)
        XCTAssertNotEqual(KeyPressDirection.startLong, KeyPressDirection.endLong)
        XCTAssertNotEqual(KeyPressDirection.short, KeyPressDirection.endLong)
    }
}
