//
//  GlkGraphicsWindow.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkWindow.h>

@interface GlkGraphicsWindow : GlkWindow {
	NSImage* windowImage;							// The image buffer for this window
	NSColor* backgroundColour;						// The background colour for this window
}

// Drawing in the graphics window
- (void) fillRect: (NSRect) rect					// Fills in an area in a solid colour
	   withColour: (NSColor*) col;
- (void) setBackgroundColour: (NSColor*) col;		// Sets the background colour of the window to the specified colour
- (void) drawImage: (NSImage*) img					// Draws an image, scaled to the given rectangle
			inRect: (NSRect) imgRect;

@end
