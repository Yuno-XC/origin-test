//
//  RemoteViewModelTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

@MainActor
final class RemoteViewModelTests: XCTestCase {
    func testSendAction_forwardsToAdapter() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.sendAction(.menu)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(adapter.sentActions.last, .menu)
    }

    func testSendCharacter_empty_doesNotSend() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.sendCharacter("")
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(adapter.sentActions.isEmpty)
    }

    func testSendCharacter_nonEmpty_sendsTextInput() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.sendCharacter("z")
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(adapter.sentActions.last, .textInput("z"))
    }

    func testDeleteCharacter_forwardsToAdapter() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.deleteCharacter()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(adapter.sentActions.last, .deleteCharacter)
    }

    func testStartLongPress_fastForward_sendsStartLong() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.startLongPress(.fastForward)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(adapter.sentWithDirection.last?.0, .fastForward)
        XCTAssertEqual(adapter.sentWithDirection.last?.1, .startLong)
    }

    func testEndLongPress_mismatchedAction_doesNotSendEndLong() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.startLongPress(.rewind)
        try await Task.sleep(for: .milliseconds(80))
        vm.endLongPress(.fastForward)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(adapter.sentWithDirection.contains { $0.0 == .rewind && $0.1 == .endLong })
    }

    func testStopRewind_stopFastForward_endLongPressPaths() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.rewind()
        try await Task.sleep(for: .milliseconds(80))
        vm.stopRewind()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(adapter.sentWithDirection.contains { $0.0 == .rewind && $0.1 == .endLong })

        adapter.sentWithDirection.removeAll()
        vm.fastForward()
        try await Task.sleep(for: .milliseconds(80))
        vm.stopFastForward()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(adapter.sentWithDirection.contains { $0.0 == .fastForward && $0.1 == .endLong })
    }

    func testDpadAndSystemShortcuts_forwardActions() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.dpadUp()
        vm.home()
        vm.back()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(adapter.sentActions.contains(.dpadUp))
        XCTAssertTrue(adapter.sentActions.contains(.home))
        XCTAssertTrue(adapter.sentActions.contains(.back))
    }

    func testMediaAndVolumeShortcuts_forwardActions() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.playPause()
        vm.next()
        vm.previous()
        vm.volumeUp()
        vm.volumeDown()
        vm.mute()
        vm.power()
        try await Task.sleep(for: .milliseconds(400))
        let actions = adapter.sentActions
        XCTAssertTrue(actions.contains(.playPause))
        XCTAssertTrue(actions.contains(.next))
        XCTAssertTrue(actions.contains(.previous))
        XCTAssertTrue(actions.contains(.volumeUp))
        XCTAssertTrue(actions.contains(.volumeDown))
        XCTAssertTrue(actions.contains(.mute))
        XCTAssertTrue(actions.contains(.power))
    }

    func testStartLongPress_nonLongPressAction_sendsShortPress() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.startLongPress(.home)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(adapter.sentWithDirection.last?.0, .home)
        XCTAssertEqual(adapter.sentWithDirection.last?.1, .short)
    }

    func testStartLongPress_rewind_sendsStartLong() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.startLongPress(.rewind)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(adapter.sentWithDirection.last?.0, .rewind)
        XCTAssertEqual(adapter.sentWithDirection.last?.1, .startLong)
    }

    func testEndLongPress_rewind_sendsEndLong() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.startLongPress(.rewind)
        try await Task.sleep(for: .milliseconds(80))
        vm.endLongPress(.rewind)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(adapter.sentWithDirection.contains { $0.0 == .rewind && $0.1 == .endLong })
    }

    func testSendText_empty_doesNotSend() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.sendText("")
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(adapter.sentActions.isEmpty)
    }

    func testSendText_nonEmpty_sendsTextInput() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.sendText("ok")
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(adapter.sentActions.last, .textInput("ok"))
    }

    func testOpenAndCloseKeyboard_togglesTypingMode() {
        let vm = RemoteViewModel(adapter: MockTVRemoteAdapter())
        vm.openKeyboard()
        XCTAssertTrue(vm.showKeyboard)
        XCTAssertTrue(vm.isTypingMode)
        XCTAssertEqual(vm.keyboardText, "")
        vm.closeKeyboard()
        XCTAssertFalse(vm.showKeyboard)
        XCTAssertFalse(vm.isTypingMode)
    }

    func testSendEnter_forwardsToAdapter() async throws {
        let adapter = MockTVRemoteAdapter()
        let vm = RemoteViewModel(adapter: adapter)
        vm.sendEnter()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(adapter.sentActions.last, .enter)
    }
}
