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

    func show(_ name: String) {
        shown.append(name)
        whileShowing?()
    }
}

@MainActor
final class IFPaneHistoryTests: XCTestCase, @unchecked Sendable {
    private var history: IFPaneHistory!
    /// How often the history has said it changed
    private var changes = 0
    private var shown: Shown!

    override func setUp() {
        MainActor.assumeIsolated {
            super.setUp()
            changes = 0
            history = IFPaneHistory(changeHandler: { [weak self] in
                self?.changes += 1
            })
            shown = Shown()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            // Let the history forget its last event, which it does in the next pass of the run loop
            nextPass()
            history = nil
            shown = nil
            super.tearDown()
        }
    }

    /// Runs the run loop, so that what's recorded next goes in an event of its own
    private func nextPass() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    /// Records showing the name given in the event for this pass of the run loop, as a pane or its page does
    private func recordInThisPass(_ name: String) throws {
        let shown = try XCTUnwrap(shown)
        try XCTUnwrap(history.eventForThisPass()).addAction { shown.show(name) }
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

    func testTheFirstEventIsTheCurrentOne() throws {
        XCTAssertNotNil(history.eventForThisPass())
        XCTAssertEqual(changes, 1)
        XCTAssertFalse(history.canGoBackwards)
        XCTAssertFalse(history.canGoForwards)
    }

    func testWhatsRecordedInOnePassOfTheRunLoopGoesInOneEvent() throws {
        let first = try XCTUnwrap(history.eventForThisPass())
        let again = try XCTUnwrap(history.eventForThisPass())
        XCTAssertTrue(again === first)
        XCTAssertEqual(changes, 1)

        nextPass()
        let next = try XCTUnwrap(history.eventForThisPass())
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

    func testAnEventReplaysItsActionsInTheOrderTheyWereAdded() throws {
        let event = try XCTUnwrap(history.eventForThisPass())
        event.addAction { self.shown.show("a") }
        event.addAction { self.shown.show("b") }
        event.addAction { self.shown.show("c") }
        XCTAssertEqual(shown.shown, [])

        event.replay()
        XCTAssertEqual(shown.shown, ["a", "b", "c"])
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
            recordedWhileShowing.append(history.eventForThisPass())
        }
        history.goBackwards()
        XCTAssertEqual(recordedWhileShowing.count, 1)
        XCTAssertNil(recordedWhileShowing.first ?? nil)
        XCTAssertEqual(changes, 3)
        XCTAssertFalse(history.canGoBackwards)
        XCTAssertTrue(history.canGoForwards)
    }

    // MARK: - Clearing

    func testClearingLetsTheEventsGoWithWhatTheirActionsHold() throws {
        weak var event: IFHistoryEvent?
        weak var held: Shown?
        try autoreleasepool {
            let shown = Shown()
            held = shown
            let recorded = try XCTUnwrap(history.eventForThisPass())
            event = recorded
            recorded.addAction { shown.show("a") }
        }
        XCTAssertNotNil(event)
        XCTAssertNotNil(held)

        history.clear()
        XCTAssertNil(event)
        XCTAssertNil(held)
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
