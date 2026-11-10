//
//  IFPaneHistoryTests.swift
//  InformTests
//

import XCTest

/// What the history's events show, kept as they're replayed
private final class Shown: NSObject {
    private(set) var shown: [String] = []
    /// Called as something is shown, as a pane's page might record more
    var whileShowing: (() -> Void)?

    /// Dynamic, so that it's sent as a message, as the history's proxy needs
    @objc dynamic func show(_ name: String) {
        shown.append(name)
        whileShowing?()
    }
}

final class IFPaneHistoryTests: XCTestCase {
    private var history: IFPaneHistory!
    /// How often the history has said it changed
    private var changes = 0
    private var shown: Shown!

    override func setUp() {
        super.setUp()
        changes = 0
        history = IFPaneHistory(changeHandler: { [weak self] in
            self?.changes += 1
        })
        shown = Shown()
    }

    override func tearDown() {
        // Let the history forget its last event, which it does in the next pass of the run loop
        nextPass()
        history = nil
        shown = nil
        super.tearDown()
    }

    /// Runs the run loop, so that what's recorded next goes in an event of its own
    private func nextPass() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    /// Records showing the name given in the event for this pass of the run loop, as a pane's page does through its
    /// history's proxy
    private func recordInThisPass(_ name: String) throws {
        let event = try XCTUnwrap(history.event(for: NSNull()))
        event.target = shown
        // Objective-C sends it to an id, which unsafeBitCast does here
        unsafeBitCast(event.proxy as AnyObject, to: Shown.self).show(name)
    }

    /// Records showing the name given in an event of its own
    private func record(_ name: String) throws {
        try recordInThisPass(name)
        nextPass()
    }

    // MARK: - Recording

    func testANewHistoryHasNothingToGoBackOrForwardTo() {
        XCTAssertFalse(history.canGoBackwards)
        XCTAssertFalse(history.canGoForwards)

        history.goBackwards()
        history.goForwards()
        XCTAssertEqual(changes, 0)
        XCTAssertFalse(history.canGoBackwards)
        XCTAssertFalse(history.canGoForwards)
    }

    func testTheFirstEventIsAimedAtTheObjectGivenAndIsTheCurrentOne() throws {
        let event = try XCTUnwrap(history.event(for: shown!))
        XCTAssertTrue(event.target as AnyObject? === shown)
        XCTAssertEqual(changes, 1)
        XCTAssertFalse(history.canGoBackwards)
        XCTAssertFalse(history.canGoForwards)
    }

    func testWhatsRecordedInOnePassOfTheRunLoopGoesInOneEvent() throws {
        let first = try XCTUnwrap(history.event(for: shown!))
        let again = try XCTUnwrap(history.event(for: NSNull()))
        XCTAssertTrue(again === first)
        XCTAssertTrue(again.target as AnyObject? === shown)
        XCTAssertEqual(changes, 1)

        nextPass()
        let next = try XCTUnwrap(history.event(for: NSNull()))
        XCTAssertFalse(next === first)
        XCTAssertEqual(changes, 2)
        XCTAssertTrue(history.canGoBackwards)
        XCTAssertFalse(history.canGoForwards)
    }

    func testWhatsRecordedInOnePassIsReplayedTogether() throws {
        try record("a")
        try recordInThisPass("b")
        try recordInThisPass("c")
        nextPass()
        try record("d")
        XCTAssertEqual(shown.shown, [])

        history.goBackwards()
        XCTAssertEqual(shown.shown, ["b", "c"])
        history.goBackwards()
        XCTAssertEqual(shown.shown, ["b", "c", "a"])
    }

    // MARK: - Going backwards and forwards

    func testGoingBackReplaysTheEventBeforeTheCurrentOneAndGoingForwardTheOneAfter() throws {
        try record("a")
        try record("b")
        try record("c")
        XCTAssertEqual(changes, 3)
        XCTAssertTrue(history.canGoBackwards)
        XCTAssertFalse(history.canGoForwards)

        history.goBackwards()
        XCTAssertEqual(shown.shown, ["b"])
        XCTAssertEqual(changes, 4)
        XCTAssertTrue(history.canGoBackwards)
        XCTAssertTrue(history.canGoForwards)

        history.goBackwards()
        XCTAssertEqual(shown.shown, ["b", "a"])
        XCTAssertEqual(changes, 5)
        XCTAssertFalse(history.canGoBackwards)
        XCTAssertTrue(history.canGoForwards)

        // At the first event, going back does nothing
        history.goBackwards()
        XCTAssertEqual(shown.shown, ["b", "a"])
        XCTAssertEqual(changes, 5)

        history.goForwards()
        history.goForwards()
        XCTAssertEqual(shown.shown, ["b", "a", "b", "c"])
        XCTAssertEqual(changes, 7)
        XCTAssertTrue(history.canGoBackwards)
        XCTAssertFalse(history.canGoForwards)

        // At the last event, going forward does nothing
        history.goForwards()
        XCTAssertEqual(shown.shown, ["b", "a", "b", "c"])
        XCTAssertEqual(changes, 7)
    }

    func testAnEventRecordedAfterGoingBackTakesThePlaceOfThoseAfterTheCurrentOne() throws {
        try record("a")
        try record("b")
        try record("c")
        history.goBackwards()
        history.goBackwards()

        try record("d")
        XCTAssertTrue(history.canGoBackwards)
        XCTAssertFalse(history.canGoForwards)

        history.goBackwards()
        history.goForwards()
        XCTAssertEqual(shown.shown, ["b", "a", "a", "d"])
        XCTAssertFalse(history.canGoForwards)
    }

    func testNothingIsRecordedWhileAnEventIsReplayed() throws {
        try record("a")
        try record("b")

        var recordedWhileShowing: [IFHistoryEvent?] = []
        shown.whileShowing = { [unowned self] in
            recordedWhileShowing.append(history.event(for: NSNull()))
        }
        history.goBackwards()
        XCTAssertEqual(recordedWhileShowing.count, 1)
        XCTAssertNil(recordedWhileShowing.first ?? nil)
        XCTAssertEqual(changes, 3)
        XCTAssertFalse(history.canGoBackwards)
        XCTAssertTrue(history.canGoForwards)
    }

    // MARK: - Clearing

    func testClearingLetsTheEventsGoWithWhatTheyreAimedAt() throws {
        weak var event: IFHistoryEvent?
        weak var target: Shown?
        try autoreleasepool {
            let aimedAt = Shown()
            target = aimedAt
            let recorded = try XCTUnwrap(history.event(for: aimedAt))
            event = recorded
            unsafeBitCast(recorded.proxy as AnyObject, to: Shown.self).show("a")
        }
        XCTAssertNotNil(event)
        XCTAssertNotNil(target)

        history.clear()
        XCTAssertNil(event)
        XCTAssertNil(target)
        XCTAssertFalse(history.canGoBackwards)
    }

    func testOnceClearedTheHistoryIsAsANewOne() throws {
        try record("a")
        try record("b")
        history.clear()
        XCTAssertFalse(history.canGoBackwards)
        XCTAssertFalse(history.canGoForwards)

        // What's recorded next is the first event
        try record("c")
        XCTAssertFalse(history.canGoBackwards)
        XCTAssertFalse(history.canGoForwards)
        try record("d")
        history.goBackwards()
        XCTAssertEqual(shown.shown, ["c"])
    }
}
