//
//  IFViewAnimator.h
//  Inform
//
//  Created by Andrew Hunter on 01/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, IFViewAnimationStyle) {
	IFAnimateLeft,
	IFAnimateRight,
	IFAnimateUp,
	IFAnimateDown
};

///
/// A class that can be used to perform various animations for a particular view
///
@interface IFViewAnimator : NSView

// Animating
/// Set how long the animation should take
- (void) setTime: (NSTimeInterval) animationTime;
/// Prepares to animate, using the specified view as a template
- (void) prepareToAnimateView: (NSView*) view
                    focusView: (nullable NSView*) focusView;

/// Begins animating the specified view so that transitions from the state set in
/// \c prepareToAnimateView to the new state, sending the specified message to the specified
/// object when it finishes
- (void) animateTo: (NSView*) view
         focusView: (nullable NSView*) focusView
			 style: (IFViewAnimationStyle) style
	   sendMessage: (nullable SEL) finishedMessage
		  toObject: (nullable id) whenFinished;

@end

NS_ASSUME_NONNULL_END
