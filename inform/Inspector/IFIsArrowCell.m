//
//  IFIsArrowCell.m
//  Inform
//
//  Created by Andrew Hunter on Fri Apr 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsArrowCell.h"
#import "IFImageCache.h"


@implementation IFIsArrowCell {
    NSRect currentFrame;					// Used for mouse tracking

    int state;								// Current state of the arrow

    // The 'up/down' animation
    int endState;							// Final state after the animation has completed
    NSTimer* animationTimeout;				// Timer that fires when the animation should complete

    NSView* lastControlView;				// Last control view to contain this cell
}

#define AnimationTime 0.05

static NSImage* arrow1;
static NSImage* arrow2;
static NSImage* arrow3; 

+ (void) initialize {
	arrow1 = [IFImageCache loadResourceImage: @"App/Inspector/Arrow-Closed.png"];
	arrow2 = [IFImageCache loadResourceImage: @"App/Inspector/Arrow-PartOpen.png"];
	arrow3 = [IFImageCache loadResourceImage: @"App/Inspector/Arrow-Open.png"];
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		[self setIntValue: 1];
		animationTimeout = nil;
	}
	
	return self;
}

- (void) dealloc {
	if (animationTimeout) {
		[animationTimeout invalidate];
		animationTimeout = nil;
	}
	
}

- (NSImage*) activeImage {
	int value = [self intValue];
	NSImage* img = arrow1;
	
	switch (value)
	{
		case 1: img = arrow1; break;
		case 2: img = arrow2; break;
		case 3: img = arrow3; break;
		default:
			NSLog(@"Warning: bad value: %i", value);
	}
	
	return img;
}

- (void)drawInteriorWithFrame: (NSRect)cellFrame 
					   inView: (NSView *)controlView {
	NSImage* img = [self activeImage];
	
	NSRect imgRect;
	
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [img size];
		
	[img drawInRect: cellFrame
		   fromRect: imgRect
		  operation: NSCompositeSourceOver
		   fraction: 1.0
     respectFlipped: [[self controlView] isFlipped]
              hints: nil];
	
	if ([controlView isKindOfClass: [NSControl class]]) lastControlView = controlView;
}

- (NSView*) controlView {
	NSView* superView = [super controlView];
	if (superView != nil) return superView;
	
	return lastControlView;
}

- (BOOL)trackMouse:(NSEvent *)theEvent
			inRect:(NSRect)cellFrame
			ofView:(NSView *)controlView 
	  untilMouseUp:(BOOL)untilMouseUp {
	currentFrame = cellFrame;
	
	return [super trackMouse: theEvent
					  inRect: cellFrame
					  ofView: controlView
				untilMouseUp: untilMouseUp];
}

- (BOOL) point: (NSPoint) point
	   inImage: (NSImage*) img {
	NSPoint actualPoint = point;
	
	actualPoint.x -= currentFrame.origin.x;
	actualPoint.y -= currentFrame.origin.y;
	
	[img lockFocus];
	
	// Note: will fail if the image is scaled for some reason
	NSColor* col = NSReadPixel(point);
	BOOL res = [col alphaComponent] > 0.1; // 0.1 = 'fudge factor'
	
	[img unlockFocus];
	
	return res;
}

- (BOOL)startTrackingAt: (NSPoint)startPoint 
				 inView: (NSView *)controlView {
	return [self point: startPoint 
			   inImage: [self activeImage]];
}

- (BOOL)continueTracking:(NSPoint)lastPoint
					  at:(NSPoint)currentPoint 
				  inView:(NSView *)controlView {
	return YES;
}

- (void)stopTracking: (NSPoint)lastPoint
				  at: (NSPoint)stopPoint 
			  inView: (NSView *)controlView
		   mouseIsUp: (BOOL)flag {
	if ([self point: stopPoint
			inImage: [self activeImage]]) {		
		[self performFlip];
	}
}

- (void) performFlip {
	// The final state
	endState = [self intValue]==3?1:3;
	
	// Set to the 'in between' state
	[self setIntValue: 2];
	
	// Create the timer
	if (animationTimeout) {
		[animationTimeout invalidate];
		animationTimeout = nil;
	}
	
	animationTimeout = [NSTimer timerWithTimeInterval: AnimationTime
											   target: self
											 selector: @selector(finishRotating:)
											 userInfo: nil
											  repeats: NO];
	[[NSRunLoop currentRunLoop] addTimer: animationTimeout
								 forMode: NSDefaultRunLoopMode];
}

- (void) finishRotating: (void*) userInfo {	
	if (animationTimeout) {
		animationTimeout = nil;
	}
	
	// Update to the final state
	[self setIntValue: endState];
	
	// Send the action
	[(NSControl*)[self controlView] sendAction: [self action]
											to: [self target]];
}

- (NSSize)cellSize {
	return [arrow1 size];
}

- (NSSize)cellSizeForBounds:(NSRect)aRect {
	return [arrow1 size];
}

+ (BOOL)prefersTrackingUntilMouseUp {
	return YES;
}

// State
- (void) setIntValue: (int) value {
	state = value;
	[(NSControl*)[self controlView] updateCell: self];
}

- (int) intValue {
	return state;
}

@end
