//
//  RemoteViewModelTests.swift
//  TVremoteTests
//

import XCTest
@testable import TVremote

@MainActor
final class RemoteViewModelTests: XCTestCase {
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
