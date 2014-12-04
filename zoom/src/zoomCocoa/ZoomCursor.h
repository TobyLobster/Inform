//
//  ZoomCursor.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jun 25 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// Blinking cursor thing

@interface ZoomCursor : NSObject {
	NSRect cursorRect;
	BOOL isBlinking, isShown, isActive, isFirst;
	BOOL blink;
	
	NSPoint cursorPos;
	
	BOOL lastVisible, lastActive;
	
	id<NSObject> delegate;
	
	NSTimer* flasher;
}

// Drawing
- (void) draw;
- (BOOL) visible;
- (BOOL) activeStyle;

// Positioning
- (void) positionAt: (NSPoint) pt
		   withFont: (NSFont*) font;
- (void) positionInString: (NSString*) string
		   withAttributes: (NSDictionary*) attributes
		 atCharacterIndex: (int) index;

- (NSRect) cursorRect;

// Display status
- (void) setBlinking: (BOOL) blink;  // Cursor blinks on/off
- (void) setShown:    (BOOL) shown;  // Cursor shown/hidden
- (void) setActive:   (BOOL) active; // Whether or not the cursor is 'active' (ie the window has focus)
- (void) setFirst:    (BOOL) first;  // Whether or not the cursor's view is the first responder

// Delegate
- (id) delegate;
- (void) setDelegate: (id<NSObject>) delegate;

@end

@interface NSObject(ZoomCursorDelegate)

- (void) blinkCursor: (ZoomCursor*) sender;

@end

