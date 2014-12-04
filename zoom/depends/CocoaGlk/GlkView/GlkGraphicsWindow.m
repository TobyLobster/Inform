//
//  GlkGraphicsWindow.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkGraphicsWindow.h"


@implementation GlkGraphicsWindow

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
		NSSize imgSize = frame.size;
		
		if (imgSize.width <= 0) imgSize.width = 1;
		if (imgSize.height <= 0) imgSize.height = 1;
		
		// Construct a buffer image for this window
		windowImage = [[NSImage alloc] initWithSize: imgSize];
		
		// Fill it in white
		[windowImage lockFocus];
		
		[[NSColor whiteColor] set];
		NSRectFill(NSMakeRect(0,0, frame.size.width, frame.size.height));
		
		[windowImage unlockFocus];		
		
		backgroundColour = [[NSColor whiteColor] retain];
    }

    return self;
}

- (void) dealloc {
	[windowImage release]; windowImage = nil;
	[backgroundColour release]; backgroundColour = nil;
	
	[super dealloc];
}

- (void) clearWindow {
	NSSize imgSize = [windowImage size];
	
	// Fill in the background colour
	[windowImage lockFocus];
	
	[backgroundColour set];
	NSRectFill(NSMakeRect(0,0, imgSize.width, imgSize.height));
	
	[windowImage unlockFocus];
}

- (void) clear {
	// Clear the window
	[self clearWindow];
	
	// Generate a redraw event for this window
	GlkEvent* evt = [[GlkEvent alloc] initWithType: evtype_Redraw
								  windowIdentifier: [self identifier]];
	
	[target queueEvent: [evt autorelease]];
}

- (void) setFrame: (NSRect) frame {	
	// Resize the buffer image (if the new size is bigger than the old size)
	NSSize oldSize = [windowImage size];
	
	if (oldSize.width < frame.size.width || oldSize.height < frame.size.height) {
		// Resize and clear
		[windowImage setSize: NSMakeSize(frame.size.width + 8.0, frame.size.height + 8.0)];
		[self clear];
	}
	
	// Call the superclass
	[super setFrame: frame];
}

- (NSRect) convertGlkToImageCoords: (NSRect) r {
	NSRect res = r;
	NSSize size = [windowImage size];
	
	res.origin.y = size.height - res.origin.y - res.size.height;
	
	return res;
}

- (void)drawRect:(NSRect)rect {
	// Draw the buffer image
	[windowImage drawInRect: rect
				   fromRect: [self convertGlkToImageCoords: rect]
				  operation: NSCompositeSourceOver
				   fraction: 1.0];
}

- (void) mouseDown: (NSEvent*) event {
	NSRect bounds = [self bounds];
	NSPoint mousePos = [self convertPoint: [event locationInWindow] 
								 fromView: nil];
	
	int clickX = mousePos.x;
	int clickY = NSMaxY(bounds)-mousePos.y;
	
	if (mouseInput) {
		// Generate the event
		GlkEvent* evt = [[GlkEvent alloc] initWithType: evtype_MouseInput
									  windowIdentifier: [self identifier]
												  val1: clickX
												  val2: clickY];
		
		// ... send it
		[target queueEvent: [evt autorelease]];
	} else {
		[super mouseDown: event];
	}
}

// = Styles =

- (void) setStyles: (NSDictionary*) newStyles {
	// Set the styles in the superclass
	[super setStyles: newStyles];
	
	// Set the background colour according to the style hints
	GlkStyle* mainStyle = [self style: style_Normal];
	
	[backgroundColour release];
	backgroundColour = [[mainStyle backColour] copy];
	
	// Clear the window
	[self clear];
}

// = Layout =

- (void) layoutInRect: (NSRect) parentRect {
	// Set the frame
	[self setFrame: parentRect];
	
	// Request a sync if necessary
	GlkSize newSize = [self glkSize];
	if (newSize.width != lastSize.width || newSize.height != lastSize.height) {
		[containingView requestClientSync];
	}
	lastSize = [self glkSize];
}

- (float) widthForFixedSize: (unsigned) size {
	// Graphics sizes are already in pixels
	return size;
}

- (float) heightForFixedSize: (unsigned) size {
	// Graphics sizes are already in pixels
	return size;
}

- (GlkSize) glkSize {
	// The GlkSize of this window is the same as the 'actual' size in pixels
	NSRect frame = [self frame];
	
	GlkSize res;
	
	res.width = frame.size.width;
	res.height = frame.size.height;
	
	return res;
}

// = Drawing in the graphics window =

- (void) fillRect: (NSRect) rect
	   withColour: (NSColor*) col {
	[windowImage lockFocus];
	
	rect = [self convertGlkToImageCoords: rect];
	
	[col set];
	NSRectFill(rect);
	
	[windowImage unlockFocus];
	
	[self setNeedsDisplay: YES];
}

- (void) setBackgroundColour: (NSColor*) col {
	[backgroundColour release];
	backgroundColour = [col copy];
}

- (void) drawImage: (NSImage*) img
			inRect: (NSRect) imgRect {
	NSSize imgSize = [img size];
	
	imgRect = [self convertGlkToImageCoords: imgRect];
	
	[windowImage lockFocus];
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	[img drawInRect: imgRect
		   fromRect: NSMakeRect(0,0, imgSize.width, imgSize.height)
		  operation: NSCompositeSourceOver
		   fraction: 1.0];
	[windowImage unlockFocus];
	
	[self setNeedsDisplay: YES];
}

// = NSAccessibility =

- (id)accessibilityAttributeValue:(NSString *)attribute {
	if ([attribute isEqualToString: NSAccessibilityRoleDescriptionAttribute]) {
		return [NSString stringWithFormat: @"GLK graphics window%@%@", lineInput?@", waiting for commands":@"", charInput?@", waiting for a key press":@""];;
	} 
	
	return [super accessibilityAttributeValue: attribute];
}

@end
