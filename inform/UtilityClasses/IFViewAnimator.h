//
//  IFViewAnimator.h
//  Inform
//
//  Created by Andrew Hunter on 01/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(int, IFViewAnimationStyle) {
	IFAnimateLeft,
	IFAnimateRight,
	IFAnimateUp,
	IFAnimateDown,
	IFAnimateCrossFade,
	IFFloatIn,
	IFFloatOut
};

///
/// A class that can be used to perform various animations for a particular view
///
@interface IFViewAnimator : NSView

// Caching views
/// Returns an image with the contents of the specified view
+ (NSImage*) cacheView: (NSView*) view;
/// Caches a specific image as the start of an animation
- (void) cacheStartView: (NSView*) view;

// Animating
/// Set how long the animation should take
- (void) setTime: (NSTimeInterval) animationTime;
/// Prepares to animate, using the specified view as a template
- (void) prepareToAnimateView: (NSView*) view
                    focusView: (NSView*) focusView;

/// Begins animating the specified view so that transitions from the state set in
/// \c prepareToAnimateView to the new state, sending the specified message to the specified
/// object when it finishes
- (void) animateTo: (NSView*) view
         focusView: (NSView*) focusView
			 style: (IFViewAnimationStyle) style
	   sendMessage: (SEL) finishedMessage
		  toObject: (id) whenFinished;
/// Abandons any running animation
- (void) finishAnimation;

@end

@interface NSObject(IFViewAnimation)

/// Optional method implemented by views that is a request from the animation view to remove any applicable tracking rectangles
- (void) removeTrackingRects;
/// Optional method implemented by views that is a request from the animation view to add any tracking rectangles back again
- (void) setTrackingRects;

@end
