//
//  IFViewAnimator.m
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

#import "IFViewAnimator.h"
#import <QuartzCore/QuartzCore.h>


@implementation IFViewAnimator {
    // Snapshots of the start and the end of the animation
    NSImage* startImage;
    NSImage* endImage;

    // Animation settings
    NSTimeInterval animationTime;

    // Information used while animating
    NSRect originalFrame;
    NSView* originalView;
    NSView* originalSuperview;
    NSView* originalFocusView;
    // Whether the view has been put back to animate. Until then, the view is
    // the one taken out to prepare, which finishing puts back; afterwards,
    // another animator may have taken the view out, and it's left to that one.
    BOOL viewPutBack;

    // The CoreAnimation layers holding the two snapshots while animating
    CALayer* startLayer;
    CALayer* endLayer;

    id finishedObject;
    SEL finishedMessage;
}

#pragma mark - Initialisation

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
		animationTime = 0.2;
        self.wantsLayer = YES;
    }
    return self;
}

- (void) dealloc {
	[self finishAnimation];
}

#pragma mark - Caching views

+ (NSImage*) cacheView: (NSView*) view {
    NSSize imgSize = view.bounds.size;

    // Make sure the view is fully laid out and drawn before we snapshot it.
    // This replaces the old mid-animation "recache" hack in -drawRect:.
    [view layoutSubtreeIfNeeded];
    [view displayIfNeeded];

    NSBitmapImageRep *bir = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    bir.size = imgSize;
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bir];

    NSImage* image = [[NSImage alloc]initWithSize:imgSize];
    [image addRepresentation:bir];
    return image;
}

#pragma mark - Animating

- (void) setTime: (NSTimeInterval) newAnimationTime {
	animationTime = newAnimationTime;
}

- (void) finishAnimation {
	if (originalView != nil) {
        // Tear down the animation layers
        [startLayer removeFromSuperlayer];
        [endLayer removeFromSuperlayer];
        startLayer = nil;
        endLayer = nil;

		// Restore the original view
		[self removeFromSuperview];

		NSRect frame = originalFrame;
		frame.size = originalView.frame.size;

		originalView.frame = frame;
		if (!viewPutBack && originalView.superview != originalSuperview) {
			[originalSuperview addSubview: originalView];
		}
		[originalView setNeedsDisplay: YES];
        [originalView.window makeFirstResponder:originalFocusView];

		 originalView = nil;
         originalFocusView = nil;
		 originalSuperview = nil;
		viewPutBack = NO;

		// Perform whichever action was requested at the end of the animation
		if (finishedObject) {
            // Send finished message
            [finishedObject performSelector: finishedMessage
                                 withObject: self
                                 afterDelay: 0.0];
			finishedObject = nil;
		}
	}
}

- (void) prepareToAnimateView: (NSView*) view
                    focusView: (NSView*) focusView {
	[self finishAnimation];

	// Cache the initial view
	startImage = [[self class] cacheView: view];

	// Replace the specified view with the animating view (ie, this view)
	originalView = view;
	originalSuperview = view.superview;
	originalFrame = view.frame;
    originalFocusView = focusView;

	[originalView removeFromSuperviewWithoutNeedingDisplay];
	self.frame = originalFrame;
	[originalSuperview addSubview: self];

	self.autoresizingMask = originalView.autoresizingMask;
}

// Begins animating the specified view so that transitions from the state set in
// prepareToAnimateView to the new state, sending the specified message to the specified
// object when it finishes
- (void) animateTo: (NSView*) view
         focusView: (NSView*) focusView
			 style: (IFViewAnimationStyle) style
	   sendMessage: (SEL) finMessage
		  toObject: (id) whenFinished {
	// Remember the object to send the 'animation finished' message to
	finishedObject = whenFinished;
	finishedMessage	= finMessage;

	// Replace the specified view with the animating view (ie, this view)
	originalView = view;
	originalFrame = view.frame;
    originalFocusView = focusView;

	self.frame = originalFrame;
	[originalSuperview addSubview: self];

	// Put the view back in the window, underneath this one, before taking its
	// picture, so that it's laid out and drawn in the window. A view drawn while
	// it was out of the window could be shown in the wrong place once it was
	// back (source text too low, under a blank band, until it was redrawn).
	[originalSuperview addSubview: originalView
					   positioned: NSWindowBelow
					   relativeTo: self];
	viewPutBack = YES;

	// Create the final image
	endImage = [[self class] cacheView: view];

	// Run the transition using CoreAnimation
	[self runAnimationWithStyle: style];
}

#pragma mark - CoreAnimation

// Convert a snapshot NSImage into a CGImage suitable for a layer's contents
static CGImageRef IFCGImageFromImage(NSImage* image) {
    if (image == nil) return NULL;
    return [image CGImageForProposedRect: NULL context: nil hints: nil];
}

- (void) runAnimationWithStyle: (IFViewAnimationStyle) style {
    NSRect bounds = self.bounds;

    // If we have nothing to draw, just finish immediately.
    if (NSIsEmptyRect(bounds)) {
        [self finishAnimation];
        return;
    }

    // Match the backing store so snapshots stay crisp on Retina displays
    CGFloat scale = self.window.backingScaleFactor;
    if (scale <= 0.0) scale = 1.0;

    startLayer = [CALayer layer];
    startLayer.frame = bounds;
    startLayer.contentsScale = scale;
    startLayer.contents = (__bridge id)IFCGImageFromImage(startImage);

    endLayer = [CALayer layer];
    endLayer.frame = bounds;
    endLayer.contentsScale = scale;
    endLayer.contents = (__bridge id)IFCGImageFromImage(endImage);

    [self.layer addSublayer: endLayer];
    [self.layer addSublayer: startLayer];

    CGPoint centre = CGPointMake(NSMidX(bounds), NSMidY(bounds));
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;

    // Where the 'start' (old) layer slides to, and where the 'end' (new)
    // layer slides from. The layer y axis points up (the animator view is
    // not flipped), matching the geometry of the original -drawRect: code.
    CGPoint startTo = centre;   // old layer: centre -> off screen
    CGPoint endFrom = centre;   // new layer: off screen -> centre

    switch (style) {
        case IFAnimateLeft:     // old exits left, new enters from right
            startTo = CGPointMake(centre.x - w, centre.y);
            endFrom = CGPointMake(centre.x + w, centre.y);
            break;
        case IFAnimateRight:    // old exits right, new enters from left
            startTo = CGPointMake(centre.x + w, centre.y);
            endFrom = CGPointMake(centre.x - w, centre.y);
            break;
        case IFAnimateUp:       // old exits top, new enters from bottom
            startTo = CGPointMake(centre.x, centre.y + h);
            endFrom = CGPointMake(centre.x, centre.y - h);
            break;
        case IFAnimateDown:     // old exits bottom, new enters from top
            startTo = CGPointMake(centre.x, centre.y - h);
            endFrom = CGPointMake(centre.x, centre.y + h);
            break;
    }

    CAMediaTimingFunction* timing =
        [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];

    __weak IFViewAnimator* weakSelf = self;

    [CATransaction begin];
    [CATransaction setCompletionBlock: ^{
        [weakSelf finishAnimation];
    }];

    // Slide the old layer out and the new layer in
    startLayer.position = startTo;
    CABasicAnimation* out = [CABasicAnimation animationWithKeyPath: @"position"];
    out.fromValue = [NSValue valueWithPoint: NSPointFromCGPoint(centre)];
    out.toValue = [NSValue valueWithPoint: NSPointFromCGPoint(startTo)];
    out.duration = animationTime;
    out.timingFunction = timing;
    [startLayer addAnimation: out forKey: @"slide"];

    endLayer.position = centre;
    CABasicAnimation* in = [CABasicAnimation animationWithKeyPath: @"position"];
    in.fromValue = [NSValue valueWithPoint: NSPointFromCGPoint(endFrom)];
    in.toValue = [NSValue valueWithPoint: NSPointFromCGPoint(centre)];
    in.duration = animationTime;
    in.timingFunction = timing;
    [endLayer addAnimation: in forKey: @"slide"];

    [CATransaction commit];
}

@end
