//
//  GlkTextGridWindow.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkWindow.h>
#import <GlkView/GlkTextWindow.h>

@interface GlkTextGridWindow : GlkTextWindow {
	int lineInputLength;							// The amount of line input that we have accepted so far
	
	int width,height;								// Current character width/height
	int xpos,ypos;									// Current cursor position. Top left is 0,0.
	
	NSString* nextInputLine;						// The next input line to display
}

@end
