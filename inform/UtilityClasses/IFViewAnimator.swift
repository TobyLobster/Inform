//
//  IFViewAnimator.swift
//  Inform
//
//  Created by Andrew Hunter on 01/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//
//  Rewritten to use CoreAnimation (see issue #46). Instead of driving the
//  transition from an NSTimer and manually compositing two bitmaps in
//  -drawRect: every tick, we snapshot the 'from' and 'to' views into two
//  CALayers and let CoreAnimation slide them on the GPU, vsync-synced. The
//  public API is unchanged, so callers need no modification.
//

import AppKit
import QuartzCore

// Convert a snapshot NSImage into a CGImage suitable for a layer's contents
private func cgImage(from image: NSImage?) -> CGImage? {
    guard let image else { return nil }
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

@objc @implementation extension IFViewAnimator {
    // Snapshots of the start and the end of the animation
    private final var startImage: NSImage?
    private final var endImage: NSImage?

    // Animation settings
    private final var animationTime: TimeInterval = 0.0

    // Information used while animating
    private final var originalFrame = NSRect.zero
    private final var originalView: NSView?
    private final var originalSuperview: NSView?
    private final var originalFocusView: NSView?
    // Whether the view has been put back to animate. Until then, the view is
    // the one taken out to prepare, which finishing puts back; afterwards,
    // another animator may have taken the view out, and it's left to that one.
    private final var viewPutBack = false

    // The CoreAnimation layers holding the two snapshots while animating
    private final var startLayer: CALayer?
    private final var endLayer: CALayer?

    private final var finishedObject: Any?
    private final var finishedMessage: Selector?

    // MARK: - Initialisation

    public override init(frame: NSRect) {
        super.init(frame: frame)
        // Initialization code here.
        animationTime = 0.2
        wantsLayer = true
    }

    /// Swift requires this, as `init(frame:)` is overridden. The Objective-C didn't override `initWithCoder:`, so
    /// this doesn't set the view up either: animators are only made with `init`.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        // Views are let go of on the main thread
        MainActor.assumeIsolated {
            finishAnimation()
        }
    }

    // MARK: - Caching views

    private static func cacheView(_ view: NSView) -> NSImage {
        let imgSize = view.bounds.size

        // Make sure the view is fully laid out and drawn before we snapshot it.
        // This replaces the old mid-animation "recache" hack in -drawRect:.
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        let bir = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        bir?.size = imgSize
        if let bir {
            view.cacheDisplay(in: view.bounds, to: bir)
        }

        let image = NSImage(size: imgSize)
        if let bir {
            image.addRepresentation(bir)
        }
        return image
    }

    // MARK: - Animating

    func setTime(_ newAnimationTime: TimeInterval) {
        animationTime = newAnimationTime
    }

    private final func finishAnimation() {
        if let originalView {
            // Tear down the animation layers
            startLayer?.removeFromSuperlayer()
            endLayer?.removeFromSuperlayer()
            startLayer = nil
            endLayer = nil

            // Restore the original view
            removeFromSuperview()

            var frame = originalFrame
            frame.size = originalView.frame.size

            originalView.frame = frame
            if !viewPutBack && originalView.superview !== originalSuperview {
                originalSuperview?.addSubview(originalView)
            }
            originalView.needsDisplay = true
            originalView.window?.makeFirstResponder(originalFocusView)

            self.originalView = nil
            originalFocusView = nil
            originalSuperview = nil
            viewPutBack = false

            // Perform whichever action was requested at the end of the animation
            if let finishedObject {
                // Send finished message
                if let finishedMessage {
                    (finishedObject as AnyObject).perform(finishedMessage,
                                                          with: self,
                                                          afterDelay: 0.0)
                }
                self.finishedObject = nil
            }
        }
    }

    @objc(prepareToAnimateView:focusView:)
    func prepare(toAnimate view: NSView, focus focusView: NSView?) {
        finishAnimation()

        // Cache the initial view
        startImage = type(of: self).cacheView(view)

        // Replace the specified view with the animating view (ie, this view)
        originalView = view
        originalSuperview = view.superview
        originalFrame = view.frame
        originalFocusView = focusView

        view.removeFromSuperviewWithoutNeedingDisplay()
        frame = originalFrame
        originalSuperview?.addSubview(self)

        autoresizingMask = view.autoresizingMask
    }

    // Begins animating the specified view so that transitions from the state set in
    // prepareToAnimateView to the new state, sending the specified message to the specified
    // object when it finishes
    @objc(animateTo:focusView:style:sendMessage:toObject:)
    func animate(to view: NSView,
                 focus focusView: NSView?,
                 style: IFViewAnimationStyle,
                 sendMessage finMessage: Selector?,
                 to whenFinished: Any?) {
        // Remember the object to send the 'animation finished' message to
        finishedObject = whenFinished
        finishedMessage = finMessage

        // Replace the specified view with the animating view (ie, this view)
        originalView = view
        originalFrame = view.frame
        originalFocusView = focusView

        frame = originalFrame
        originalSuperview?.addSubview(self)

        // Put the view back in the window, underneath this one, before taking its
        // picture, so that it's laid out and drawn in the window. A view drawn while
        // it was out of the window could be shown in the wrong place once it was
        // back (source text too low, under a blank band, until it was redrawn).
        originalSuperview?.addSubview(view,
                                      positioned: .below,
                                      relativeTo: self)
        viewPutBack = true

        // Create the final image
        endImage = type(of: self).cacheView(view)

        // Run the transition using CoreAnimation
        runAnimation(withStyle: style)
    }

    // MARK: - CoreAnimation

    private final func runAnimation(withStyle style: IFViewAnimationStyle) {
        let bounds = self.bounds

        // If we have nothing to draw, just finish immediately.
        if NSIsEmptyRect(bounds) {
            finishAnimation()
            return
        }

        // Match the backing store so snapshots stay crisp on Retina displays
        var scale = window?.backingScaleFactor ?? 0.0
        if scale <= 0.0 { scale = 1.0 }

        let startLayer = CALayer()
        startLayer.frame = bounds
        startLayer.contentsScale = scale
        startLayer.contents = cgImage(from: startImage)
        self.startLayer = startLayer

        let endLayer = CALayer()
        endLayer.frame = bounds
        endLayer.contentsScale = scale
        endLayer.contents = cgImage(from: endImage)
        self.endLayer = endLayer

        layer?.addSublayer(endLayer)
        layer?.addSublayer(startLayer)

        let centre = CGPoint(x: NSMidX(bounds), y: NSMidY(bounds))
        let w = bounds.size.width
        let h = bounds.size.height

        // Where the 'start' (old) layer slides to, and where the 'end' (new)
        // layer slides from. The layer y axis points up (the animator view is
        // not flipped), matching the geometry of the original -drawRect: code.
        var startTo = centre   // old layer: centre -> off screen
        var endFrom = centre   // new layer: off screen -> centre

        switch style {
        case .animateLeft:      // old exits left, new enters from right
            startTo = CGPoint(x: centre.x - w, y: centre.y)
            endFrom = CGPoint(x: centre.x + w, y: centre.y)
        case .animateRight:     // old exits right, new enters from left
            startTo = CGPoint(x: centre.x + w, y: centre.y)
            endFrom = CGPoint(x: centre.x - w, y: centre.y)
        case .animateUp:        // old exits top, new enters from bottom
            startTo = CGPoint(x: centre.x, y: centre.y + h)
            endFrom = CGPoint(x: centre.x, y: centre.y - h)
        case .animateDown:      // old exits bottom, new enters from top
            startTo = CGPoint(x: centre.x, y: centre.y - h)
            endFrom = CGPoint(x: centre.x, y: centre.y + h)
        @unknown default:       // neither layer moves, as the Objective-C's switch had no case for it
            break
        }

        let timing = CAMediaTimingFunction(name: .easeInEaseOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.finishAnimation()
        }

        // Slide the old layer out and the new layer in
        startLayer.position = startTo
        let slideOut = CABasicAnimation(keyPath: "position")
        slideOut.fromValue = NSValue(point: centre)
        slideOut.toValue = NSValue(point: startTo)
        slideOut.duration = animationTime
        slideOut.timingFunction = timing
        startLayer.add(slideOut, forKey: "slide")

        endLayer.position = centre
        let slideIn = CABasicAnimation(keyPath: "position")
        slideIn.fromValue = NSValue(point: endFrom)
        slideIn.toValue = NSValue(point: centre)
        slideIn.duration = animationTime
        slideIn.timingFunction = timing
        endLayer.add(slideIn, forKey: "slide")

        CATransaction.commit()
    }
}
