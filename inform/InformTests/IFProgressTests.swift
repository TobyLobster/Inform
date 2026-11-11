//
//  IFProgressTests.swift
//  InformTests
//

import XCTest

/// A delegate that remembers what it's told
private final class RecordingDelegate: NSObject, IFProgressDelegate {
    private(set) var events: [String] = []

    func progressIndicator(_ indicator: IFProgress, percentage newPercentage: CGFloat) {
        events.append("percentage \(newPercentage)")
    }

    func progressIndicator(_ indicator: IFProgress, message newMessage: String?) {
        events.append("message \(newMessage ?? "nil")")
    }

    func progressIndicatorStartStory(_ indicator: IFProgress) {
        events.append("start story")
    }

    func progressIndicatorStopStory(_ indicator: IFProgress) {
        events.append("stop story")
    }

    func progressIndicatorStart(_ indicator: IFProgress) {
        events.append("start progress")
    }

    func progressIndicatorStop(_ indicator: IFProgress) {
        events.append("stop progress")
    }
}

/// A delegate that implements none of the delegate's methods
private final class SilentDelegate: NSObject, IFProgressDelegate {
}

/// An object to cancel with, which remembers how it was asked
private final class CancelTarget: NSObject {
    private(set) var senders: [Any?] = []
    private(set) var onMainThread: [Bool] = []

    @objc func stop(_ sender: Any?) {
        senders.append(sender)
        onMainThread.append(Thread.isMainThread)
    }
}

@MainActor
final class IFProgressTests: XCTestCase {

    private func makeProgress(priority: Int32 = IFProgressPriorityCompiler, canCancel: Bool = true) -> IFProgress {
        return IFProgress(priority: priority, showsProgressBar: true, canCancel: canCancel)
    }

    func testStartsWithWhatItsGiven() {
        let progress = IFProgress(priority: IFProgressPriorityRunGame, showsProgressBar: false, canCancel: true)

        XCTAssertEqual(progress.priority, IFProgressPriorityRunGame)
        XCTAssertFalse(progress.showsProgressBar)
        XCTAssertTrue(progress.canCancel)
        XCTAssertEqual(progress.percentage, 0)
        XCTAssertNil(progress.message)
        XCTAssertFalse(progress.isInProgress)
        XCTAssertFalse(progress.isCancelled)
        XCTAssertNil(progress.delegate)

        let other = IFProgress(priority: IFProgressPrioritySyntax, showsProgressBar: true, canCancel: false)
        XCTAssertEqual(other.priority, IFProgressPrioritySyntax)
        XCTAssertTrue(other.showsProgressBar)
        XCTAssertFalse(other.canCancel)
    }

    func testTellsItsDelegateOfThePercentage() {
        let progress = makeProgress()
        let delegate = RecordingDelegate()
        progress.delegate = delegate

        progress.percentage = 50

        XCTAssertEqual(progress.percentage, 50)
        XCTAssertEqual(delegate.events, ["percentage 50.0"])
    }

    func testTellsItsDelegateOfTheMessage() {
        let progress = makeProgress()
        let delegate = RecordingDelegate()
        progress.delegate = delegate

        let message = NSMutableString(string: "Compiling")
        progress.message = message as String
        message.append(" more")
        progress.message = nil

        XCTAssertNil(progress.message)
        XCTAssertEqual(delegate.events, ["message Compiling", "message nil"])
    }

    func testKeepsACopyOfTheMessage() {
        let progress = makeProgress()
        let message = NSMutableString(string: "Compiling")

        progress.setValue(message, forKey: "message")
        message.append(" more")

        XCTAssertEqual(progress.message, "Compiling")
    }

    func testStartsAndStopsProgress() {
        let progress = makeProgress()
        let delegate = RecordingDelegate()
        progress.delegate = delegate
        progress.percentage = 50

        progress.start()

        XCTAssertTrue(progress.isInProgress)
        // The percentage starts again, without the delegate being told
        XCTAssertEqual(progress.percentage, 0)
        XCTAssertEqual(delegate.events, ["percentage 50.0", "start progress"])

        progress.percentage = 75
        progress.stop()

        XCTAssertFalse(progress.isInProgress)
        XCTAssertEqual(progress.percentage, 0)
        XCTAssertEqual(delegate.events, ["percentage 50.0", "start progress", "percentage 75.0", "stop progress"])
    }

    func testTellsItsDelegateOfAStory() {
        let progress = makeProgress()
        let delegate = RecordingDelegate()
        progress.delegate = delegate

        progress.startStory()
        XCTAssertFalse(progress.isInProgress)
        progress.stopStory()

        XCTAssertEqual(delegate.events, ["start story", "stop story"])
    }

    func testWorksWithADelegateThatImplementsNothing() {
        let progress = makeProgress()
        let delegate = SilentDelegate()
        progress.delegate = delegate

        progress.percentage = 50
        progress.message = "Compiling"
        progress.start()
        progress.startStory()
        progress.stopStory()
        progress.stop()

        XCTAssertEqual(progress.message, "Compiling")
        XCTAssertFalse(progress.isInProgress)
    }

    func testHoldsItsDelegateWeakly() {
        let progress = makeProgress()
        weak var weakDelegate: RecordingDelegate?

        autoreleasepool {
            let delegate = RecordingDelegate()
            weakDelegate = delegate
            progress.delegate = delegate
            XCTAssertNotNil(progress.delegate)
        }

        XCTAssertNil(weakDelegate)
        XCTAssertNil(progress.delegate)
        // With no delegate, nothing is told
        progress.percentage = 50
        XCTAssertEqual(progress.percentage, 50)
    }

    func testCancelsWithItsAction() {
        let progress = makeProgress()
        let target = CancelTarget()
        progress.setCancelAction(#selector(CancelTarget.stop(_:)), for: target)

        progress.cancel()

        XCTAssertTrue(progress.isCancelled)
        // The object is given itself
        XCTAssertEqual(target.senders.count, 1)
        XCTAssertTrue(target.senders.first as AnyObject? === target)
    }

    func testCancelsWithoutAnAction() {
        let progress = makeProgress()

        progress.cancel()

        XCTAssertTrue(progress.isCancelled)
    }

    func testDoesntSendItsActionToAnObjectWithoutIt() {
        let progress = makeProgress()
        let target = NSObject()
        progress.setCancelAction(#selector(CancelTarget.stop(_:)), for: target)

        progress.cancel()

        XCTAssertTrue(progress.isCancelled)
    }

    func testStaysCancelled() {
        let progress = makeProgress()
        let target = CancelTarget()
        progress.setCancelAction(#selector(CancelTarget.stop(_:)), for: target)
        progress.cancel()

        progress.start()
        progress.stop()
        XCTAssertTrue(progress.isCancelled)

        // Cancelling again sends the action again
        progress.cancel()
        XCTAssertEqual(target.senders.count, 2)
    }

    func testCancelsOnTheMainThread() {
        let progress = makeProgress()
        let target = CancelTarget()
        progress.setCancelAction(#selector(CancelTarget.stop(_:)), for: target)
        let cancelled = expectation(description: "Cancelled")

        DispatchQueue.global().async {
            progress.cancel()
            // The action has been sent before cancelling returns
            XCTAssertEqual(target.onMainThread, [true])
            cancelled.fulfill()
        }

        wait(for: [cancelled], timeout: 5)
        XCTAssertTrue(progress.isCancelled)
    }
}
