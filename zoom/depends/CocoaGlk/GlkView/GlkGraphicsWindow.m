//
//  GlkGraphicsWindow.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import "GlkGraphicsWindow.h"
#import <GlkView/GlkPairWindow.h>
#import <GlkView/GlkView.h>

@implementation GlkGraphicsWindow

- (id)initWithFrame:(GlkRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
		GlkCocoaSize imgSize = frame.size;
		
		if (imgSize.width <= 0) imgSize.width = 1;
		if (imgSize.height <= 0) imgSize.height = 1;
		
		// Construct a buffer image for this window
		windowImage = [[GlkSuperImage alloc] initWithSize: imgSize];
		
		// Fill it in white
		[windowImage lockFocus];
		
		[[GlkColor whiteColor] set];
		GlkRectFill(GlkMakeRect(0,0, frame.size.width, frame.size.height));
		
		[windowImage unlockFocus];		
		
		backgroundColour = [GlkColor whiteColor];
    }

    return self;
}

- (void) clearWindow {
	GlkCocoaSize imgSize = [windowImage size];
	
	// Fill in the background colour
	[windowImage lockFocus];
	
	[backgroundColour set];
	GlkRectFill(GlkMakeRect(0,0, imgSize.width, imgSize.height));
	
	[windowImage unlockFocus];
}

- (void) clear {
	// Clear the window
	[self clearWindow];
	
	// Generate a redraw event for this window
	GlkEvent* evt = [[GlkEvent alloc] initWithType: evtype_Redraw
								  windowIdentifier: [self glkIdentifier]];
	
	[target queueEvent: evt];
}

- (void) setFrame: (GlkRect) frame {
	// Resize the buffer image (if the new size is bigger than the old size)
	GlkCocoaSize oldSize = [windowImage size];
	
	if (oldSize.width < frame.size.width || oldSize.height < frame.size.height) {
		// Resize and clear
		[windowImage setSize: NSMakeSize(frame.size.width + 8.0, frame.size.height + 8.0)];
		[self clear];
	}
	
	// Call the superclass
	[super setFrame: frame];
}

- (GlkRect) convertGlkToImageCoords: (GlkRect) r {
	GlkRect res = r;
	GlkCocoaSize size = [windowImage size];
	
	res.origin.y = size.height - res.origin.y - res.size.height;
	
	return res;
}

- (void)drawRect:(GlkRect)rect {
	// Draw the buffer image
#if defined(COCOAGLK_IPHONE)
#else
	[windowImage drawInRect: rect
				   fromRect: [self convertGlkToImageCoords: rect]
				  operation: NSCompositingOperationSourceOver
				   fraction: 1.0];
#endif
}

#if !defined(COCOAGLK_IPHONE)
- (void) mouseDown: (NSEvent*) event {
	NSRect bounds = [self bounds];
	NSPoint mousePos = [self convertPoint: [event locationInWindow] 
								 fromView: nil];
	
	int clickX = (int)mousePos.x;
	int clickY = (int)(NSMaxY(bounds)-mousePos.y);
	
	if (mouseInput) {
		// Generate the event
		GlkEvent* evt = [[GlkEvent alloc] initWithType: evtype_MouseInput
									  windowIdentifier: [self glkIdentifier]
												  val1: clickX
												  val2: clickY];
		
		// ... send it
		[target queueEvent: evt];
	} else {
		[super mouseDown: event];
	}
}
#endif

#pragma mark - Styles

- (void) setStyles: (NSDictionary*) newStyles {
	// Set the styles in the superclass
	[super setStyles: newStyles];
	
	// Set the background colour according to the style hints
	GlkStyle* mainStyle = [self style: style_Normal];
	
	backgroundColour = [[mainStyle backColour] copy];
	
	// Clear the window
	[self clear];
}

#pragma mark - Layout

- (void) layoutInRect: (GlkRect) parentRect {
	// Set the frame
	[self setFrame: parentRect];
	
	// Request a sync if necessary
	GlkSize newSize = [self glkSize];
	if (newSize.width != lastSize.width || newSize.height != lastSize.height) {
		[containingView requestClientSync];
	}
	lastSize = [self glkSize];
}

- (CGFloat) widthForFixedSize: (unsigned) size {
	// Graphics sizes are already in pixels
	return size;
}

- (CGFloat) heightForFixedSize: (unsigned) size {
	// Graphics sizes are already in pixels
	return size;
}

- (GlkSize) glkSize {
	// The GlkSize of this window is the same as the 'actual' size in pixels
	GlkRect frame = [self frame];
	
	GlkSize res;
	
	res.width = (int)frame.size.width;
	res.height = (int)frame.size.height;
	
	return res;
}

#pragma mark - Drawing in the graphics window

- (void) fillRect: (GlkRect) rect
	   withColour: (GlkColor*) col {
#if defined(COCOAGLK_IPHONE)
	UIGraphicsBeginImageContext(windowImage.size);
	[windowImage drawInRect:CGRectMake(0, 0, windowImage.size.width, windowImage.size.height)];

	rect = [self convertGlkToImageCoords: rect];
	
	[col set];
	UIRectFill(rect);

	[windowImage release];
	windowImage = [UIGraphicsGetImageFromCurrentImageContext() retain];
	UIGraphicsEndImageContext();
	
	[self setNeedsDisplay];
#else
	[windowImage lockFocus];
	
	rect = [self convertGlkToImageCoords: rect];
	
	[col set];
	NSRectFill(rect);
	
	[windowImage unlockFocus];
	
	[self setNeedsDisplay: YES];
#endif
}

@synthesize backgroundColour;

- (void) drawImage: (GlkSuperImage*) img
			inRect: (GlkRect) imgRect {
#if defined(COCOAGLK_IPHONE)
	imgRect = [self convertGlkToImageCoords: imgRect];
	
	//UIGraphicsImageRenderer *render = [[UIGraphicsImageRenderer alloc] initWithSize:imgSize];
	UIGraphicsBeginImageContext(windowImage.size);
	[windowImage drawInRect:CGRectMake(0, 0, windowImage.size.width, windowImage.size.height)];
	[img drawInRect:imgRect];
	[windowImage release];
	windowImage = [UIGraphicsGetImageFromCurrentImageContext() retain];
	UIGraphicsEndImageContext();
	
	[self setNeedsDisplay];
#else
	imgRect = [self convertGlkToImageCoords: imgRect];
	
	[windowImage lockFocus];
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	[img drawInRect: imgRect
		   fromRect: NSZeroRect
		  operation: NSCompositingOperationSourceOver
		   fraction: 1.0];
	[windowImage unlockFocus];
	
	[self setNeedsDisplay: YES];
#endif
}

#pragma mark - NSAccessibility

-(NSString *)accessibilityRoleDescription {
	return [NSString stringWithFormat: @"GLK graphics window%@%@", lineInput?@", waiting for commands":@"", charInput?@", waiting for a key press":@""];
}

@end
