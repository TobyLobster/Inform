//
//  IFViewAnimator.m
//  Inform
//
//  Created by Andrew Hunter on 01/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "IFViewAnimator.h"


@implementation IFViewAnimator {
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

#pragma mark - Initialisation

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
		animationTime = 0.2;
    }
    return self;
}

- (void) dealloc {
	[self finishAnimation];
}

#pragma mark - Caching views

+ (void) detrackView: (NSView*) view {
	if ([view respondsToSelector: @selector(removeTrackingRects)]) {
		[view removeTrackingRects];
	}
}

+ (void) trackView: (NSView*) view {
	if ([view respondsToSelector: @selector(setTrackingRects)]) {
		[view setTrackingRects];
	}
}

+ (NSImage*) cacheView: (NSView*) view {
    NSSize mySize = view.bounds.size;
    NSSize imgSize = NSMakeSize( mySize.width, mySize.height );
    
    NSBitmapImageRep *bir = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    bir.size = imgSize;
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bir];
    
    NSImage* image = [[NSImage alloc]initWithSize:imgSize];
    [image addRepresentation:bir];
    return image;
}

- (void) cacheStartView: (NSView*) view {
	startImage = [[self class] cacheView: view];
}

#pragma mark - Animating

- (void) setTime: (NSTimeInterval) newAnimationTime {
	animationTime = newAnimationTime;
}

- (void) finishAnimation {
	if (originalView != nil) {
		// Restore the original view
		[self removeFromSuperview];
		
		NSRect frame = originalFrame;
		frame.size = originalView.frame.size;
		
		originalView.frame = frame;
		[originalSuperview addSubview: originalView];
		[originalView setNeedsDisplay: YES];
        [originalView.window makeFirstResponder:originalFocusView];
		[IFViewAnimator trackView: originalView];
				
		 originalView = nil;
         originalFocusView = nil;
		 originalSuperview = nil;
		
		// Finish up the timer
		if (animationTimer) {
			[animationTimer invalidate];
            animationTimer = nil;
		}
		
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
	[self cacheStartView: view];

	// Replace the specified view with the animating view (ie, this view)
	originalView = view;
	originalSuperview = view.superview;
	originalFrame = view.frame;
    originalFocusView = focusView;
		
	[IFViewAnimator detrackView: originalView];
	[originalView removeFromSuperviewWithoutNeedingDisplay];
	self.frame = originalFrame;
	[originalSuperview addSubview: self];
	[self setNeedsDisplay: YES];
	
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
	whenStarted = [NSDate date];
	
	// Remember the object to send the 'animation finished' message to
	finishedObject = whenFinished;
	finishedMessage	= finMessage;
	
	// Create the final image
	endImage = [[self class] cacheView: view];
	
	// Replace the specified view with the animating view (ie, this view)
	originalView = view;
	originalFrame = view.frame;
    originalFocusView = focusView;
	
	[IFViewAnimator detrackView: originalView];
	self.frame = originalFrame;
	[originalSuperview addSubview: self];
	[self setNeedsDisplay: YES];
	
	// Start running the animation
	animationStyle = style;
	animationTimer = [NSTimer timerWithTimeInterval: 0.01
											  target: self
											selector: @selector(animationTick)
											userInfo: nil
											 repeats: YES];
	
	[[NSRunLoop currentRunLoop] addTimer: animationTimer
								 forMode: NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: animationTimer
								 forMode: NSEventTrackingRunLoopMode];
}

- (CGFloat) percentDone {
	NSTimeInterval timePassed = -whenStarted.timeIntervalSinceNow;
    CGFloat done = ((CGFloat)timePassed)/((CGFloat)animationTime);
	
	if (done < 0) done = 0;
	if (done > 1) done = 1.0;
	
	done = -2.0*done*done*done + 3.0*done*done;
	
	return done;
}

- (void) animationTick {
	if ([self percentDone] >= 1.0)
		[self finishAnimation];
	else
		[self setNeedsDisplay: YES];
}

#pragma mark - Drawing

static BOOL ViewNeedsDisplay(NSView* view) {
	BOOL result = NO;
	
	if (view == nil) return NO;
	if (view.needsDisplay) {
		[view setNeedsDisplay: NO];
		result = YES;
	}
	
	for ( NSView* subview in view.subviews ) {
		if (ViewNeedsDisplay(subview)) result = YES;
	}
	
	return result;
}

- (void)drawRect:(NSRect)rect {
	// Recache the view if it wants to be redrawn
	if (ViewNeedsDisplay(originalView) && [self percentDone] < 0.25) {
		endImage = [[self class] cacheView: originalView];
	}
	
	// Draw the appropriate animation frame
    CGFloat percentDone = [self percentDone];
    CGFloat percentNotDone = 1.0-percentDone;
	
	NSRect bounds = self.bounds;
	NSSize startSize = startImage.size;
	NSSize endSize = endImage.size;
	NSRect startFrom, startTo;
	NSRect endFrom, endTo;
	
	switch (animationStyle) {
		case IFAnimateLeft:
			// Work out where to place the images
			startFrom.origin = NSMakePoint(startSize.width*percentDone, 0);
			startFrom.size = NSMakeSize(startSize.width*percentNotDone, startSize.height);
			startTo.origin = NSMakePoint(0, NSMaxY(bounds)-startSize.height);
			startTo.size = startFrom.size;

			endFrom.origin = NSMakePoint(0, 0);
			endFrom.size = NSMakeSize(endSize.width*percentDone, endSize.height);
			endTo.origin = NSMakePoint(startSize.width*percentNotDone, NSMaxY(bounds)-endSize.height);
			endTo.size = endFrom.size;
			
			// Draw them
			[startImage drawInRect: startTo
						  fromRect: startFrom
						 operation: NSCompositingOperationSourceOver
						  fraction: 1.0];
			[endImage drawInRect: endTo
						fromRect: endFrom
					   operation: NSCompositingOperationSourceOver
						fraction: 1.0];
			break;

		case IFAnimateRight:
			// Work out where to place the images
			startFrom.origin = NSMakePoint(0, 0);
			startFrom.size = NSMakeSize(startSize.width*percentNotDone, startSize.height);
			startTo.origin = NSMakePoint(startSize.width*percentDone, NSMaxY(bounds)-startSize.height);
			startTo.size = startFrom.size;
			
			endFrom.origin = NSMakePoint(endSize.width*percentNotDone, 0);
			endFrom.size = NSMakeSize(endSize.width*percentDone, endSize.height);
			endTo.origin = NSMakePoint(0, NSMaxY(bounds)-endSize.height);
			endTo.size = endFrom.size;
			
			// Draw them
			[startImage drawInRect: startTo
						  fromRect: startFrom
						 operation: NSCompositingOperationSourceOver
						  fraction: 1.0];
			[endImage drawInRect: endTo
						fromRect: endFrom
					   operation: NSCompositingOperationSourceOver
						fraction: 1.0];
			break;

		case IFAnimateUp:
			// Work out where to place the images
			startFrom.origin = NSMakePoint(0, 0);
			startFrom.size = NSMakeSize(startSize.width, startSize.height*percentNotDone);
			startTo.origin = NSMakePoint(0, NSMaxY(bounds)-startSize.height*percentNotDone);
			startTo.size = startFrom.size;
			
			endFrom.origin = NSMakePoint(0, endSize.height*percentNotDone);
			endFrom.size = NSMakeSize(endSize.width, endSize.height*percentDone);
			endTo.origin = NSMakePoint(0, NSMaxY(bounds)-endSize.height);
			endTo.size = endFrom.size;
			
			// Draw them
			[startImage drawInRect: startTo
						  fromRect: startFrom
						 operation: NSCompositingOperationSourceOver
						  fraction: 1.0];
			[endImage drawInRect: endTo
						fromRect: endFrom
					   operation: NSCompositingOperationSourceOver
						fraction: 1.0];
			break;

		case IFAnimateDown:
			// Work out where to place the images
			startFrom.origin = NSMakePoint(0, startSize.height*percentDone);
			startFrom.size = NSMakeSize(startSize.width, startSize.height*percentNotDone);
			startTo.origin = NSMakePoint(0, NSMaxY(bounds)-startSize.height);
			startTo.size = startFrom.size;
			
			endFrom.origin = NSMakePoint(0, 0);
			endFrom.size = NSMakeSize(endSize.width, endSize.height*percentDone);
			endTo.origin = NSMakePoint(0, NSMaxY(bounds)-endSize.height*percentDone);
			endTo.size = endFrom.size;
			
			// Draw them
			[startImage drawInRect: startTo
						  fromRect: startFrom
						 operation: NSCompositingOperationSourceOver
						  fraction: 1.0];
			[endImage drawInRect: endTo
						fromRect: endFrom
					   operation: NSCompositingOperationSourceOver
						fraction: 1.0];
			break;
			
		case IFAnimateCrossFade:
			// Work out where to place the images
			startFrom.origin = NSMakePoint(0, 0);
			startFrom.size = NSMakeSize(startSize.width, startSize.height);
			startTo = startFrom;
			
			endFrom.origin = NSMakePoint(0, 0);
			endFrom.size = NSMakeSize(endSize.width, endSize.height);
			endTo = endFrom;
			
			// Draw them
			[startImage drawInRect: startTo
						  fromRect: startFrom
						 operation: NSCompositingOperationSourceOver
						  fraction: 1.0];
			[endImage drawInRect: endTo
						fromRect: endFrom
					   operation: NSCompositingOperationSourceOver
						fraction: percentDone];
			break;
			
		case IFFloatIn:
		{
			// New view appears to 'float' in from above
			startTo.origin = bounds.origin;
			startTo.size = startSize;
			startFrom.origin = NSMakePoint(0,0);
			startFrom.size = startSize;
			
			// Draw the old view
			[startImage drawInRect: startTo
						  fromRect: startFrom
						 operation: NSCompositingOperationSourceOver
						  fraction: 1.0];
			
			// Draw the new view
			endFrom.origin = NSMakePoint(0,0);
			endFrom.size = endSize;
			endTo = endFrom;
			endTo.origin = bounds.origin;
			
            CGFloat scaleFactor = 0.95 + 0.05*percentDone;
			endTo.size.height *= scaleFactor;
			endTo.size.width *= scaleFactor;
			endTo.origin.x += (endFrom.size.width - endTo.size.width) / 2;
			endTo.origin.y += (endFrom.size.height - endTo.size.height) + 10.0*percentNotDone;
			
			[endImage drawInRect: endTo
						fromRect: endFrom
					   operation: NSCompositingOperationSourceOver
						fraction: percentDone];
			break;
		}

		case IFFloatOut:
		{
			// Old view appears to 'float' out above
			endTo.origin = bounds.origin;
			endTo.size = endSize;
			endFrom.origin = NSMakePoint(0,0);
			endFrom.size = endSize;
			
			// Draw the old view
			[endImage drawInRect: endTo
						fromRect: endFrom
					   operation: NSCompositingOperationSourceOver
						fraction: 1.0];
			
			// Draw the new view
			startFrom.origin = NSMakePoint(0,0);
			startFrom.size = startSize;
			startTo = startFrom;
			startTo.origin = bounds.origin;
			
            CGFloat scaleFactor = 0.95 + 0.05*percentNotDone;
			startTo.size.height *= scaleFactor;
			startTo.size.width *= scaleFactor;
			startTo.origin.x += (startFrom.size.width - startTo.size.width) / 2;
			startTo.origin.y += (startFrom.size.height - startTo.size.height) + 10.0*percentDone;
			
			[startImage drawInRect: startTo
						  fromRect: startFrom
						 operation: NSCompositingOperationSourceOver
						  fraction: percentNotDone];
			break;
		}
	}
}

@end
