//
//  IFMaintenanceTaskTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFMaintenanceTaskTests: XCTestCase, @unchecked Sendable {

    private var maintenance: IFMaintenanceTask {
        return IFMaintenanceTask.shared
    }

    /// A notification name of the tests' own, so that nothing in the app observes it
    private func makeNotificationName() -> NSNotification.Name {
        return NSNotification.Name("IFMaintenanceTaskTests-\(UUID().uuidString)")
    }

    /// A new temporary file, not yet written, removed after the test
    private func makeFile() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder.appendingPathComponent("Output.txt")
    }

    /// Queues a task that adds a line to a file
    private func queueAppending(_ line: String, to file: URL, notifyType: NSNotification.Name) {
        maintenance.queue("/bin/sh",
                          withArguments: ["-c", "echo \"$0\" >> \"$1\"", line, file.path],
                          notifyType: notifyType)
    }

    /// Queues a task that does nothing
    private func queueNothing(notifyType: NSNotification.Name) {
        maintenance.queue("/usr/bin/true", withArguments: [], notifyType: notifyType)
    }

    private func contents(of file: URL) throws -> String {
        return try String(contentsOf: file, encoding: .utf8)
    }

    override func setUpWithError() throws {
        try MainActor.assumeIsolated {
            try super.setUpWithError()

            // Wait for anything already queued, such as a census, so that each test starts with nothing running
            let idle = makeNotificationName()
            let finished = expectation(forNotification: idle, object: maintenance)
            queueNothing(notifyType: idle)
            wait(for: [finished], timeout: 60)
        }
    }

    func testThereIsOneSharedMaintenanceTask() {
        XCTAssertTrue(IFMaintenanceTask.shared === IFMaintenanceTask.shared)
    }

    func testRunsTheCommandWithItsArguments() throws {
        let file = try makeFile()
        let done = makeNotificationName()
        let finished = expectation(forNotification: done, object: maintenance)

        queueAppending("Hello, Sailor", to: file, notifyType: done)

        wait(for: [finished], timeout: 10)
        XCTAssertEqual(try contents(of: file), "Hello, Sailor\n")
    }

    func testRunsTasksOneAfterAnotherInTheOrderQueued() throws {
        let file = try makeFile()
        let done = makeNotificationName()
        let finished = expectation(forNotification: done, object: maintenance)

        maintenance.queue("/bin/sh", withArguments: ["-c", "sleep 0.2; echo first >> \"$0\"", file.path], notifyType: done)
        queueAppending("second", to: file, notifyType: done)

        wait(for: [finished], timeout: 10)
        XCTAssertEqual(try contents(of: file), "first\nsecond\n")
    }

    func testTellsWhenTasksStartOnceForEachRun() {
        nonisolated(unsafe) var started = 0
        let observer = NotificationCenter.default.addObserver(forName: .IFMaintenanceTasksStarted,
                                                              object: maintenance, queue: nil) { _ in
            started += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let first = makeNotificationName()
        let firstFinished = expectation(forNotification: first, object: maintenance)
        queueNothing(notifyType: makeNotificationName())
        queueNothing(notifyType: first)
        wait(for: [firstFinished], timeout: 10)
        XCTAssertEqual(started, 1)

        let second = makeNotificationName()
        let secondFinished = expectation(forNotification: second, object: maintenance)
        queueNothing(notifyType: second)
        wait(for: [secondFinished], timeout: 10)
        XCTAssertEqual(started, 2)
    }

    func testOnlyTheLastTasksNotificationIsPosted() {
        let earlier = makeNotificationName()
        nonisolated(unsafe) var toldEarlier = 0
        let observer = NotificationCenter.default.addObserver(forName: earlier, object: maintenance, queue: nil) { _ in
            toldEarlier += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let last = makeNotificationName()
        let finished = expectation(forNotification: last, object: maintenance)
        queueNothing(notifyType: earlier)
        queueNothing(notifyType: last)

        wait(for: [finished], timeout: 10)
        XCTAssertEqual(toldEarlier, 0)
    }

    func testSkipsATaskTheSameAsTheLastOneWaiting() throws {
        let file = try makeFile()
        let done = makeNotificationName()
        let finished = expectation(forNotification: done, object: maintenance)

        // The first task runs at once, so the next two wait behind it
        queueNothing(notifyType: makeNotificationName())
        queueAppending("Hello", to: file, notifyType: done)
        queueAppending("Hello", to: file, notifyType: done)

        wait(for: [finished], timeout: 10)
        XCTAssertEqual(try contents(of: file), "Hello\n")
    }

    func testDoesntSkipATaskTheSameAsTheOneRunning() throws {
        let file = try makeFile()
        let done = makeNotificationName()
        let finished = expectation(forNotification: done, object: maintenance)

        // The first task runs at once, and may need running again
        queueAppending("Hello", to: file, notifyType: done)
        queueAppending("Hello", to: file, notifyType: done)

        wait(for: [finished], timeout: 10)
        XCTAssertEqual(try contents(of: file), "Hello\nHello\n")
    }

    func testDoesntSkipATaskWithDifferentArgumentsOrNotification() throws {
        let file = try makeFile()
        let done = makeNotificationName()
        let alsoDone = makeNotificationName()
        let finished = expectation(forNotification: alsoDone, object: maintenance)

        queueNothing(notifyType: makeNotificationName())
        queueAppending("Hello", to: file, notifyType: done)
        queueAppending("Goodbye", to: file, notifyType: done)
        queueAppending("Goodbye", to: file, notifyType: alsoDone)
        maintenance.queue("/bin/sh", withArguments: ["-c", "echo \"$0\" >> \"$1\"", "Goodbye", file.path, "extra"],
                          notifyType: alsoDone)

        wait(for: [finished], timeout: 10)
        XCTAssertEqual(try contents(of: file), "Hello\nGoodbye\nGoodbye\nGoodbye\n")
    }

    func testDoesntSkipATaskWithADifferentCommand() throws {
        let file = try makeFile()
        let done = makeNotificationName()
        let finished = expectation(forNotification: done, object: maintenance)
        let arguments = ["-c", "echo \"$0\" >> \"$1\"", "Hello", file.path]

        queueNothing(notifyType: makeNotificationName())
        maintenance.queue("/bin/sh", withArguments: arguments, notifyType: done)
        maintenance.queue("/bin/zsh", withArguments: arguments, notifyType: done)

        wait(for: [finished], timeout: 10)
        XCTAssertEqual(try contents(of: file), "Hello\nHello\n")
    }

    // MARK: - Commands that can't be run

    /// As when an external Inform Core folder (Advanced preferences) hasn't got it
    private let missingCommand = "/nonexistent/ni"

    func testPassesOverACommandThatCantBeRun() throws {
        let file = try makeFile()
        let done = makeNotificationName()
        let finished = expectation(forNotification: done, object: maintenance)

        // The first task runs at once, so the next two wait behind it
        queueNothing(notifyType: makeNotificationName())
        maintenance.queue(missingCommand, withArguments: [], notifyType: done)
        queueAppending("Hello", to: file, notifyType: done)

        wait(for: [finished], timeout: 10)
        XCTAssertEqual(try contents(of: file), "Hello\n")
    }

    func testTellsWhenACommandThatCantBeRunIsTheLast() {
        let done = makeNotificationName()
        let finished = expectation(forNotification: done, object: maintenance)

        maintenance.queue(missingCommand, withArguments: [], notifyType: done)

        wait(for: [finished], timeout: 10)
    }
}
