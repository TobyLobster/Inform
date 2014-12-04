//
//  ZoomLeopard.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 28/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ZoomLeopard

// = Animations =

- (void) popView: (NSView*) view									// Causes a view to do a 'pop up' animation
		duration: (NSTimeInterval) seconds
		finished: (NSInvocation*) finished;
- (void) popOutView: (NSView*) view									// Causes a view to do a 'pop out' animation
		   duration: (NSTimeInterval) seconds
		   finished: (NSInvocation*) finished;
- (void) clearLayersForView: (NSView*) view;						// Removes the layers for the specified view

- (void) fullScreenView: (NSView*) view								// Animates a view to full screen
			  fromFrame: (NSRect) oldWindowFrame
				toFrame: (NSRect) newWindowFrame;
@end

///
/// Implementation of the ZoomLeopard protocol
///
@interface ZoomLeopard : NSObject<ZoomLeopard> {
	NSMutableArray* animationsWillFinish;							// Array of animations that will finished
	NSMutableArray* finishInvocations;
}

@end
