//
//  ZoomCursor.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jun 25 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol ZoomCursorDelegate;

//! Blinking cursor thing
@interface ZoomCursor : NSObject {
	NSRect cursorRect;
	BOOL blink;
	
	NSPoint cursorPos;
	
	BOOL lastVisible, lastActive;
	
	NSTimer* flasher;
}

#pragma mark Drawing

- (void) draw;
@property (readonly, getter=isVisible) BOOL visible;
@property (readonly) BOOL activeStyle;

// Positioning
- (void) positionAt: (NSPoint) pt
		   withFont: (NSFont*) font;
- (void) positionInString: (NSString*) string
		   withAttributes: (NSDictionary<NSAttributedStringKey, id>*) attributes
		 atCharacterIndex: (NSInteger) index;

@property (readonly) NSRect cursorRect;

#pragma mark Display status

/// Cursor blinks on/off
@property (nonatomic, getter=isBlinking) BOOL blinking;
/// Cursor shown/hidden
@property (nonatomic, getter=isShown) BOOL shown;
/// Whether or not the cursor is 'active' (ie the window has focus)
@property (nonatomic, getter=isActive) BOOL active;
/// Whether or not the cursor's view is the first responder
@property (nonatomic, getter=isFirst) BOOL first;

/// Delegate
@property (weak) id<ZoomCursorDelegate> delegate;

@end

@protocol ZoomCursorDelegate <NSObject>
@optional

- (void) blinkCursor: (ZoomCursor*) sender;

@end

