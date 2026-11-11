//
//  IFNotifyingWindowTests.swift
//  InformTests
//

import XCTest

/// A window's delegate that records each first responder it's told of
private final class RecordingDelegate: NSObject, NSWindowDelegate {
    private(set) var responders: [NSResponder?] = []

    override func changeFirstResponder(_ newResponder: NSResponder?) {
        responders.append(newResponder)
    }
}

/// A view that can be the first responder, or can refuse to be, or to stop being
private final class FocusableView: NSView {
    var refuses = false
    var wontResign = false

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        return !refuses
    }

    override func resignFirstResponder() -> Bool {
        return !wontResign
    }
}

@MainActor
final class IFNotifyingWindowTests: XCTestCase {

    /// A window with a view that can be the first responder. It's never shown, and has no autosave name.
    private func windowWithView() -> (IFNotifyingWindow, FocusableView) {
        let window = IFNotifyingWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                                       styleMask: [.titled],
                                       backing: .buffered,
                                       defer: true)
        window.isReleasedWhenClosed = false
        let view = FocusableView(frame: NSRect(x: 10, y: 10, width: 50, height: 20))
        window.contentView?.addSubview(view)
        return (window, view)
    }

    func testTheDelegateIsToldOfANewFirstResponder() {
        let (window, view) = windowWithView()
        let delegate = RecordingDelegate()
        window.delegate = delegate

        XCTAssertTrue(window.makeFirstResponder(view))
        XCTAssertIdentical(window.firstResponder, view)
        XCTAssertEqual(delegate.responders.count, 1)
        XCTAssertIdentical(delegate.responders.first ?? nil, view)
    }

    /// No responder makes the window the first responder, and the delegate is told of none
    func testNoResponder() {
        let (window, view) = windowWithView()
        let delegate = RecordingDelegate()
        XCTAssertTrue(window.makeFirstResponder(view))
        window.delegate = delegate

        XCTAssertTrue(window.makeFirstResponder(nil))
        XCTAssertIdentical(window.firstResponder, window)
        XCTAssertEqual(delegate.responders.count, 1)
        XCTAssertNil(delegate.responders.first ?? nil)
    }

    /// A responder that refuses to be the first responder isn't: the window is. But AppKit says the change was made,
    /// so the delegate is told of the responder all the same, and a project's controller makes its pane active.
    func testAResponderThatRefuses() {
        let (window, view) = windowWithView()
        let delegate = RecordingDelegate()
        window.delegate = delegate
        view.refuses = true

        XCTAssertTrue(window.makeFirstResponder(view))
        XCTAssertIdentical(window.firstResponder, window)
        XCTAssertEqual(delegate.responders.count, 1)
        XCTAssertIdentical(delegate.responders.first ?? nil, view)
    }

    /// When the first responder won't stop being it, nothing changes, and the delegate isn't told
    func testAFirstResponderThatWontResign() {
        let (window, view) = windowWithView()
        let other = FocusableView(frame: NSRect(x: 100, y: 10, width: 50, height: 20))
        window.contentView?.addSubview(other)
        XCTAssertTrue(window.makeFirstResponder(view))
        let delegate = RecordingDelegate()
        window.delegate = delegate
        view.wontResign = true

        XCTAssertFalse(window.makeFirstResponder(other))
        XCTAssertIdentical(window.firstResponder, view)
        XCTAssertTrue(delegate.responders.isEmpty)
    }

    /// A window with no delegate, as a source file's window has
    func testNoDelegate() {
        let (window, view) = windowWithView()

        XCTAssertTrue(window.makeFirstResponder(view))
        XCTAssertIdentical(window.firstResponder, view)
    }
}
