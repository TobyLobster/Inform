//
//  IFViewAnimatorTests.swift
//  InformTests
//

import XCTest

final class IFViewAnimatorTests: XCTestCase {

    /// A view filled with one colour, so that a picture of it shows which view it is, and which can be focused
    private final class ColourView: NSView {
        var colour: NSColor {
            didSet { needsDisplay = true }
        }

        init(frame: NSRect, colour: NSColor) {
            self.colour = colour
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("not used")
        }

        override func draw(_ dirtyRect: NSRect) {
            colour.setFill()
            dirtyRect.fill()
        }

        override var acceptsFirstResponder: Bool { true }
    }

    /// Records the animators that send it the finished message
    private final class Receiver: NSObject {
        var animators: [IFViewAnimator] = []

        @objc func animationFinished(_ animator: IFViewAnimator) {
            animators.append(animator)
        }
    }

    private var window: NSWindow!
    private var container: NSView!
    private var red: ColourView!
    private var blue: ColourView!

    override func setUp() {
        super.setUp()
        // NSWindow moves a window made off the screen onto it, so it's moved off afterwards
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        window.contentView?.addSubview(container)

        red = ColourView(frame: NSRect(x: 10, y: 20, width: 200, height: 100), colour: .red)
        red.autoresizingMask = [.width, .maxYMargin]
        container.addSubview(red)
        blue = ColourView(frame: NSRect(x: 30, y: 40, width: 250, height: 150), colour: .blue)
    }

    override func tearDown() {
        window.close()
        window = nil
        container = nil
        red = nil
        blue = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Runs the run loop until the condition holds, or two seconds have passed
    @discardableResult
    private func wait(until condition: () -> Bool) -> Bool {
        let limit = Date(timeIntervalSinceNow: 2.0)
        while !condition() && Date() < limit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        return condition()
    }

    /// Waits for the animation to finish, and for the message it sends then, after a delay of nothing
    private func waitToFinish(_ animator: IFViewAnimator) {
        XCTAssertTrue(wait { animator.superview == nil }, "The animation didn't finish")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    /// The animation's two layers: the picture of the new view, underneath, and the picture of the old
    private func layers(of animator: IFViewAnimator) -> (end: CALayer, start: CALayer)? {
        guard let sublayers = animator.layer?.sublayers, sublayers.count == 2 else { return nil }
        return (sublayers[0], sublayers[1])
    }

    /// The colour in the middle of a layer's picture
    private func colour(of layer: CALayer) -> NSColor? {
        guard let contents = layer.contents,
              CFGetTypeID(contents as CFTypeRef) == CGImage.typeID else { return nil }
        let rep = NSBitmapImageRep(cgImage: contents as! CGImage)
        return rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)?.usingColorSpace(.sRGB)
    }

    // The picture's colour space isn't the colour's, so red comes back a little orange
    private func isRed(_ colour: NSColor?) -> Bool {
        guard let colour else { return false }
        return colour.redComponent > 0.8 && colour.greenComponent < 0.4 && colour.blueComponent < 0.4
    }

    private func isBlue(_ colour: NSColor?) -> Bool {
        guard let colour else { return false }
        return colour.redComponent < 0.4 && colour.greenComponent < 0.4 && colour.blueComponent > 0.8
    }

    private func slide(_ layer: CALayer) -> (from: NSPoint, to: NSPoint, duration: CFTimeInterval)? {
        guard let animation = layer.animation(forKey: "slide") as? CABasicAnimation,
              let from = (animation.fromValue as? NSValue)?.pointValue,
              let to = (animation.toValue as? NSValue)?.pointValue else { return nil }
        return (from, to, animation.duration)
    }

    // MARK: - Tests

    func testANewAnimator() {
        let animator = IFViewAnimator()

        XCTAssertEqual(animator.frame, .zero)
        XCTAssertTrue(animator.wantsLayer)
        XCTAssertNil(animator.superview)
    }

    func testPreparingPutsTheAnimatorInTheViewsPlace() {
        let animator = IFViewAnimator()

        animator.prepare(toAnimate: red, focus: nil)

        XCTAssertNil(red.superview)
        XCTAssertEqual(container.subviews, [animator])
        XCTAssertEqual(animator.frame, NSRect(x: 10, y: 20, width: 200, height: 100))
        XCTAssertEqual(animator.autoresizingMask, [.width, .maxYMargin])
    }

    func testAnimatingPutsTheNewViewUnderTheAnimator() {
        let animator = IFViewAnimator()
        animator.prepare(toAnimate: red, focus: nil)

        animator.animate(to: blue, focus: nil, style: .animateLeft, sendMessage: nil, to: nil)

        XCTAssertNil(red.superview)
        XCTAssertEqual(container.subviews, [blue, animator])
        XCTAssertEqual(animator.frame, NSRect(x: 30, y: 40, width: 250, height: 150))
        XCTAssertEqual(blue.frame, NSRect(x: 30, y: 40, width: 250, height: 150))
    }

    func testThePicturesAreOfTheOldViewAndTheNew() throws {
        let animator = IFViewAnimator()
        animator.prepare(toAnimate: red, focus: nil)

        animator.animate(to: blue, focus: nil, style: .animateLeft, sendMessage: nil, to: nil)

        let layers = try XCTUnwrap(layers(of: animator))
        XCTAssertTrue(isRed(colour(of: layers.start)), "The old view's picture is \(String(describing: colour(of: layers.start)))")
        XCTAssertTrue(isBlue(colour(of: layers.end)), "The new view's picture is \(String(describing: colour(of: layers.end)))")
        for layer in [layers.start, layers.end] {
            XCTAssertEqual(layer.bounds.size, NSSize(width: 250, height: 150))
            XCTAssertEqual(layer.contentsScale, window.backingScaleFactor)
        }
    }

    func testThePicturesAreOfTheViewBeforeAndAfterItChanges() throws {
        // As the Source page does, going from one section to the next
        let animator = IFViewAnimator()
        animator.prepare(toAnimate: red, focus: nil)
        red.colour = .blue

        animator.animate(to: red, focus: nil, style: .animateUp, sendMessage: nil, to: nil)

        let layers = try XCTUnwrap(layers(of: animator))
        XCTAssertTrue(isRed(colour(of: layers.start)), "The picture before is \(String(describing: colour(of: layers.start)))")
        XCTAssertTrue(isBlue(colour(of: layers.end)), "The picture after is \(String(describing: colour(of: layers.end)))")
        XCTAssertEqual(container.subviews, [red, animator])
    }

    func testEachStyleSlidesTheOldPictureOutAndTheNewIn() throws {
        // Layers' y axis points up, and the animator is 200 by 100, so its middle is at (100, 50)
        let expected: [(style: IFViewAnimationStyle, out: NSPoint, in: NSPoint)] = [
            (.animateLeft,  NSPoint(x: -100, y: 50), NSPoint(x: 300, y: 50)),
            (.animateRight, NSPoint(x: 300, y: 50),  NSPoint(x: -100, y: 50)),
            (.animateUp,    NSPoint(x: 100, y: 150), NSPoint(x: 100, y: -50)),
            (.animateDown,  NSPoint(x: 100, y: -50), NSPoint(x: 100, y: 150)),
        ]
        let middle = NSPoint(x: 100, y: 50)

        for (style, out, into) in expected {
            let animator = IFViewAnimator()
            animator.setTime(0.01)
            animator.prepare(toAnimate: red, focus: nil)
            animator.animate(to: red, focus: nil, style: style, sendMessage: nil, to: nil)

            let layers = try XCTUnwrap(layers(of: animator))
            let startSlide = try XCTUnwrap(slide(layers.start))
            let endSlide = try XCTUnwrap(slide(layers.end))
            XCTAssertEqual(startSlide.from, middle, "style \(style.rawValue)")
            XCTAssertEqual(startSlide.to, out, "style \(style.rawValue)")
            XCTAssertEqual(layers.start.position, out, "style \(style.rawValue)")
            XCTAssertEqual(endSlide.from, into, "style \(style.rawValue)")
            XCTAssertEqual(endSlide.to, middle, "style \(style.rawValue)")
            XCTAssertEqual(layers.end.position, middle, "style \(style.rawValue)")
            XCTAssertEqual(startSlide.duration, 0.01, "style \(style.rawValue)")
            XCTAssertEqual(endSlide.duration, 0.01, "style \(style.rawValue)")

            waitToFinish(animator)
        }
    }

    func testTheSlidesEaseInAndOut() throws {
        let animator = IFViewAnimator()
        animator.prepare(toAnimate: red, focus: nil)
        animator.animate(to: blue, focus: nil, style: .animateRight, sendMessage: nil, to: nil)

        let layers = try XCTUnwrap(layers(of: animator))
        for layer in [layers.start, layers.end] {
            let animation = try XCTUnwrap(layer.animation(forKey: "slide") as? CABasicAnimation)
            XCTAssertEqual(animation.timingFunction, CAMediaTimingFunction(name: .easeInEaseOut))
        }
    }

    func testASlideTakesAFifthOfASecondUnlessTold() throws {
        let animator = IFViewAnimator()
        animator.prepare(toAnimate: red, focus: nil)
        animator.animate(to: blue, focus: nil, style: .animateDown, sendMessage: nil, to: nil)

        let layers = try XCTUnwrap(layers(of: animator))
        XCTAssertEqual(try XCTUnwrap(slide(layers.start)).duration, 0.2)
        XCTAssertEqual(try XCTUnwrap(slide(layers.end)).duration, 0.2)

        let started = Date()
        waitToFinish(animator)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.15)
    }

    func testFinishingLeavesTheNewViewInPlace() {
        let animator = IFViewAnimator()
        animator.setTime(0.01)
        animator.prepare(toAnimate: red, focus: nil)
        animator.animate(to: blue, focus: nil, style: .animateLeft, sendMessage: nil, to: nil)

        waitToFinish(animator)

        XCTAssertEqual(container.subviews, [blue])
        XCTAssertNil(red.superview)
        XCTAssertEqual(blue.frame, NSRect(x: 30, y: 40, width: 250, height: 150))
        XCTAssertEqual(animator.layer?.sublayers ?? [], [])
    }

    func testTheNewViewKeepsItsSizeButGoesBackToItsPlace() {
        let animator = IFViewAnimator()
        animator.setTime(0.05)
        animator.prepare(toAnimate: red, focus: nil)
        animator.animate(to: blue, focus: nil, style: .animateLeft, sendMessage: nil, to: nil)

        blue.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        waitToFinish(animator)

        XCTAssertEqual(blue.frame, NSRect(x: 30, y: 40, width: 300, height: 200))
    }

    func testFinishingFocusesTheFocusView() {
        window.makeFirstResponder(red)
        let animator = IFViewAnimator()
        animator.setTime(0.01)
        animator.prepare(toAnimate: red, focus: nil)
        animator.animate(to: blue, focus: blue, style: .animateLeft, sendMessage: nil, to: nil)

        waitToFinish(animator)

        XCTAssertIdentical(window.firstResponder, blue)
    }

    func testFinishingWithNoFocusViewFocusesTheWindow() {
        window.makeFirstResponder(red)
        let animator = IFViewAnimator()
        animator.setTime(0.01)
        animator.prepare(toAnimate: red, focus: nil)
        animator.animate(to: red, focus: nil, style: .animateLeft, sendMessage: nil, to: nil)

        waitToFinish(animator)

        XCTAssertIdentical(window.firstResponder, window)
    }

    func testFinishingSendsTheMessage() {
        let receiver = Receiver()
        let animator = IFViewAnimator()
        animator.setTime(0.01)
        animator.prepare(toAnimate: red, focus: nil)
        animator.animate(to: blue, focus: nil, style: .animateLeft,
                         sendMessage: #selector(Receiver.animationFinished(_:)), to: receiver)
        XCTAssertEqual(receiver.animators, [])

        waitToFinish(animator)

        XCTAssertEqual(receiver.animators, [animator])
    }

    func testFinishingWithNoObjectSendsNothing() {
        let animator = IFViewAnimator()
        animator.setTime(0.01)
        animator.prepare(toAnimate: red, focus: nil)
        animator.animate(to: blue, focus: nil, style: .animateLeft,
                         sendMessage: #selector(Receiver.animationFinished(_:)), to: nil)

        waitToFinish(animator)

        XCTAssertEqual(container.subviews, [blue])
    }

    func testAViewWithNoSizeFinishesAtOnce() {
        let receiver = Receiver()
        let empty = ColourView(frame: NSRect(x: 5, y: 5, width: 0, height: 0), colour: .red)
        container.addSubview(empty)
        let animator = IFViewAnimator()
        animator.prepare(toAnimate: empty, focus: nil)

        animator.animate(to: empty, focus: nil, style: .animateUp,
                         sendMessage: #selector(Receiver.animationFinished(_:)), to: receiver)

        XCTAssertNil(animator.superview)
        XCTAssertEqual(container.subviews, [red, empty])
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(receiver.animators, [animator])
    }

    func testPreparingAgainPutsTheFirstViewBack() {
        container.addSubview(blue)
        let animator = IFViewAnimator()
        animator.prepare(toAnimate: red, focus: nil)

        animator.prepare(toAnimate: blue, focus: nil)

        XCTAssertIdentical(red.superview, container)
        XCTAssertEqual(red.frame, NSRect(x: 10, y: 20, width: 200, height: 100))
        XCTAssertNil(blue.superview)
        XCTAssertEqual(Set(container.subviews), Set([red, animator]))
        XCTAssertEqual(animator.frame, NSRect(x: 30, y: 40, width: 250, height: 150))
    }

    func testSlidingTheSameViewAgainBeforeTheFirstSlideEnds() {
        // As the Source page does, going on two sections quickly
        let first = IFViewAnimator()
        first.setTime(0.05)
        first.prepare(toAnimate: red, focus: nil)
        first.animate(to: red, focus: nil, style: .animateUp, sendMessage: nil, to: nil)
        let second = IFViewAnimator()
        second.setTime(0.1)
        second.prepare(toAnimate: red, focus: nil)
        second.animate(to: red, focus: nil, style: .animateUp, sendMessage: nil, to: nil)

        waitToFinish(first)
        waitToFinish(second)

        XCTAssertEqual(container.subviews, [red])
        XCTAssertEqual(red.frame, NSRect(x: 10, y: 20, width: 200, height: 100))
    }

    func testSlidingBackBeforeTheFirstSlideEnds() {
        // As the Source page does when Show Headings is chosen twice quickly: the first slide's view is the one the
        // second slide takes away, so finishing the first slide mustn't put it back
        let first = IFViewAnimator()
        first.setTime(0.05)
        first.prepare(toAnimate: red, focus: nil)
        first.animate(to: blue, focus: nil, style: .animateRight, sendMessage: nil, to: nil)
        let second = IFViewAnimator()
        second.setTime(0.1)
        second.prepare(toAnimate: blue, focus: nil)
        second.animate(to: red, focus: nil, style: .animateLeft, sendMessage: nil, to: nil)

        waitToFinish(first)
        XCTAssertNil(blue.superview, "The first slide put back the view the second slide took")
        waitToFinish(second)

        XCTAssertEqual(container.subviews, [red])
        XCTAssertNil(blue.superview)
    }
}
