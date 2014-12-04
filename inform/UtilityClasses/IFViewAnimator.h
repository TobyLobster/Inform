//
//  IFViewAnimator.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 01/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum IFViewAnimationStyle {
	IFAnimateLeft,
	IFAnimateRight,
	IFAnimateUp,
	IFAnimateDown,
	IFAnimateCrossFade,
	IFFloatIn,
	IFFloatOut
} IFViewAnimationStyle;

///
/// A class that can be used to perform various animations for a particular view
///
@interface IFViewAnimator : NSView {
	// The start and the end of the animation
	NSImage* startImage;
	NSImage* endImage;
	
	// Animation settings
	NSTimeInterval animationTime;
	IFViewAnimationStyle animationStyle;
	
	// Information used while animating
	NSTimer* animationTimer;
	NSRect originalFrame;
	NSView* originalView;
	NSView* originalSuperview;
    NSView* originalFocusView;
	NSDate* whenStarted;
	
	id finishedObject;
	SEL finishedMessage;
}

// Caching views
+ (NSImage*) cacheView: (NSView*) view;								// Returns an image with the contents of the specified view
- (void) cacheStartView: (NSView*) view;							// Caches a specific image as the start of an animation

// Animating
- (void) setTime: (float) animationTime;							// Set how long the animation should take
- (void) prepareToAnimateView: (NSView*) view
                    focusView: (NSView*) focusView;					// Prepares to animate, using the specified view as a template

// Begins animating the specified view so that transitions from the state set in
// prepareToAnimateView to the new state
- (void) animateTo: (NSView*) view
			 style: (IFViewAnimationStyle) style
         focusView: (NSView*) focusView;

// Begins animating the specified view so that transitions from the state set in
// prepareToAnimateView to the new state, sending the specified message to the specified
// object when it finishes
- (void) animateTo: (NSView*) view
         focusView: (NSView*) focusView
			 style: (IFViewAnimationStyle) style
	   sendMessage: (SEL) finishedMessage
		  toObject: (id) whenFinished;
- (void) finishAnimation;											// Abandons any running animation

@end

@interface NSObject(IFViewAnimation)

- (void) removeTrackingRects;										// Optional method implemented by views that is a request from the animation view to remove any applicable tracking rectangles
- (void) setTrackingRects;											// Optional method implemented by views that is a request from the animation view to add any tracking rectangles back again

@end
