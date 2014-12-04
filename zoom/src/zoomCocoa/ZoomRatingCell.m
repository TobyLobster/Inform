//
//  ZoomRatingCell.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Apr 15 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomRatingCell.h"


@implementation ZoomRatingCell

static NSImage* stars1 = nil;
static NSImage* stars2 = nil;
static NSImage* dots   = nil;

static NSSize starsSize;

+ (void) initialize {
	stars1 = [[NSImage imageNamed: @"stars-grey"] retain];
	stars2 = [[NSImage imageNamed: @"stars-red"] retain];
	dots   = [[NSImage imageNamed: @"stars-none"] retain];
	
	starsSize = [stars1 size];
}

- (void)drawInteriorWithFrame: (NSRect)cellFrame 
					   inView: (NSView *)controlView {
	[super drawInteriorWithFrame: cellFrame
						  inView: controlView];
	
	float value = 0;
	BOOL flipped = [controlView isFlipped];
	
	if ([[self objectValue] isKindOfClass: [NSNumber class]])
		value = [[self objectValue] floatValue] * 0.1;
	
	if (value < 0.0) value = 0.0;
	if (value > 1.0) value = 1.0;
	
	// Work out the size to draw our image
	NSSize size = starsSize;
	size.width *= value;
	
	if (size.width > cellFrame.size.width)
		size.width = cellFrame.size.width;
	
	// Work out the rectangle to draw in
	NSRect drawRect;
	
	drawRect.origin.x = cellFrame.origin.x + (cellFrame.size.width - starsSize.width)/2;
	drawRect.origin.y = cellFrame.origin.y + (cellFrame.size.height - starsSize.height)/2;
	drawRect.size = size;
	
	drawRect.origin.y -= 1;
	
	// Work out the rectangle to draw from
	NSRect clipRect;
	
	clipRect.origin = NSMakePoint(0,0);
	clipRect.size = size;
	
	// Draw the dots?
	if ([self isHighlighted]) {
		[dots setFlipped: flipped];
		[dots drawInRect: NSMakeRect(drawRect.origin.x, drawRect.origin.y, starsSize.width, starsSize.height)
				fromRect: NSMakeRect(0,0, starsSize.width, starsSize.height)
			   operation: NSCompositeSourceOver
				fraction: 1.0];
	}
	
	// Draw the image
	[stars1 setFlipped: flipped];
	[stars1 drawInRect: drawRect
			  fromRect: clipRect
			 operation: NSCompositeSourceOver
			  fraction: 1.0];

	[stars2 setFlipped: flipped];
	[stars2 drawInRect: drawRect
			  fromRect: clipRect
			 operation: NSCompositeSourceOver
			  fraction: value*value];
	
	// Done
}

- (void) adjustValueToPoint: (NSPoint) point
					 inView: (NSView*) controlView {
	// Work out the rectangle we're in
	NSRect drawRect;
	
	drawRect.origin.x = currentFrame.origin.x + (currentFrame.size.width - starsSize.width)/2;
	drawRect.origin.y = currentFrame.origin.y + (currentFrame.size.height - starsSize.height)/2;
	drawRect.size = starsSize;
	
	float value = (point.x - drawRect.origin.x) / drawRect.size.width;
	
	if (value > 1.0) value = 1.0;
	if (value < -1.0) value = 0.0;
	
	value *= 10.0;
	
	value = floor(value + 0.5);
	
	[self setObjectValue: [NSNumber numberWithFloat: value]];
	[(NSControl*)controlView updateCell: self];
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

- (BOOL)startTrackingAt: (NSPoint)startPoint 
				 inView: (NSView *)controlView {
	return YES;
}

- (BOOL)continueTracking:(NSPoint)lastPoint
					  at:(NSPoint)currentPoint 
				  inView:(NSView *)controlView {
	[self adjustValueToPoint: currentPoint
					  inView: controlView];

	return YES;
}

- (void)stopTracking: (NSPoint)lastPoint
				  at: (NSPoint)stopPoint 
			  inView: (NSView *)controlView
		   mouseIsUp: (BOOL)flag {
	[self adjustValueToPoint: stopPoint
					  inView: controlView];
}

+ (BOOL)prefersTrackingUntilMouseUp {
	return YES;
}

@end
