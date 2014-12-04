//
//  ZoomCursor.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jun 25 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomCursor.h"

#define BlinkInterval 0.6

@implementation ZoomCursor

// = Initialisation =
- (id) init {
	self = [super init];
	
	if (self) {
		isBlinking = NO;
		isShown    = YES;
		isActive   = YES;
		isFirst    = YES;
		
		blink      = YES;
		
		cursorRect = NSMakeRect(0,0,0,0);
		delegate   = nil;
		flasher = nil;
		
		lastVisible = [self visible];
		lastActive = [self activeStyle];
	}
	
	return self;
}

- (void) dealloc {
	if (flasher) {
		[flasher invalidate];
		[flasher release];
	}
	
	[super dealloc];
}

// = Delegate =
- (id) delegate {
	return delegate;
}

- (void) setDelegate: (id<NSObject>) dg {
	delegate = dg;
}

// = Blinking =
- (BOOL) visible {
	return (isShown&&(!isBlinking||blink));
}

- (BOOL) activeStyle {
	return (isActive&&isFirst);
}

- (void) ZCblunk {
	// Cursor has, uh, blunked
	
	// Only send the message if our visibility has changed
	BOOL nowVisible = [self visible];		
	BOOL nowActive = [self activeStyle];
	if (nowActive == lastActive &&
		nowVisible == lastVisible) {
		return;
	}

	lastVisible = nowVisible;
	lastActive = nowActive;

	// Notify the delegate that we have blinked
	if ([delegate respondsToSelector: @selector(blinkCursor:)]) {
		[(NSObject*)delegate blinkCursor: self];
	}
}

- (void) ZCblinky {
	if ([self activeStyle]) {
		blink = !blink;
	} else {
		blink = YES;
	}
	[self ZCblunk];
}

// = Drawing =
- (void) draw {
	if (![self visible]) return;

	// Cursor colour
	[[NSColor colorWithDeviceRed: 0.3
						   green: 0.8
							blue: 1.0
						   alpha: 0.6] set];
	
	// Draw the cursor
	if ([self activeStyle]) {
		[NSBezierPath strokeRect: cursorRect];
		[NSBezierPath fillRect: cursorRect];
	} else {
		[NSBezierPath strokeRect: cursorRect];
	}
}

// = Positioning =
- (void) positionAt: (NSPoint) pt
		   withFont: (NSFont*) font {
	// Cause the delegate to undraw any previous cursor
	BOOL wasShown = isShown;
	isShown = NO;
	[self ZCblunk];
	
	// Move the cursor
	// One 'en'
    float width = [@"n" sizeWithAttributes:
             [NSDictionary dictionaryWithObjectsAndKeys:
               font, NSFontAttributeName, nil]].width;
    NSLayoutManager* lm = [[[NSLayoutManager alloc] init] autorelease];
	float height = [lm defaultLineHeightForFont: font];
		
	cursorRect = NSMakeRect(pt.x, pt.y, width, height);
	
	cursorRect.origin.x = floor(cursorRect.origin.x + 0.5) + 0.5;
	cursorRect.origin.y = floor(cursorRect.origin.y + 0.5) + 0.5;
	cursorRect.size.width = floor(cursorRect.size.width + 0.5);
	cursorRect.size.height = floor(cursorRect.size.height + 0.5);
	
	// Redraw
	isShown = wasShown;
	[self ZCblunk];
	
	cursorPos = pt;
}

- (void) positionInString: (NSString*) string
		   withAttributes: (NSDictionary*) attributes
		 atCharacterIndex: (int) index {
	// Cause the delegate to undraw any previous cursor
	BOOL wasShown = isShown;
	isShown = NO;
	[self ZCblunk];
	
	NSFont* font = [attributes objectForKey: NSFontAttributeName];
	
	// Move the cursor
	// One 'en'
    float width = [@"n" sizeWithAttributes:
                   [NSDictionary dictionaryWithObjectsAndKeys:
                    font, NSFontAttributeName, nil]].width;
    NSLayoutManager* lm = [[[NSLayoutManager alloc] init] autorelease];
	float height = [lm defaultLineHeightForFont: font];
	float offset = [[string substringToIndex: index] sizeWithAttributes: attributes].width;
	
	cursorRect = NSMakeRect(cursorPos.x+offset, cursorPos.y, width, height);

	// Redraw
	isShown = wasShown;
	blink = YES;
	[self ZCblunk];
}

- (NSRect) cursorRect {
	return NSInsetRect(cursorRect, -2.0, -2.0);
}

// = Display status =
- (void) setBlinking: (BOOL) blnk {
	if (blnk == isBlinking) return;
	
	isBlinking = blnk;
	
	if (blnk == NO) {
		blink = YES;
		[self ZCblunk];
		
		if (flasher) {
			[flasher invalidate];
			[flasher release];
			flasher = nil;
		}
	} else {
		if (!flasher) {
			flasher = [NSTimer timerWithTimeInterval: BlinkInterval
											  target: self
											selector: @selector(ZCblinky)
											userInfo: nil
											 repeats: YES];
			[[NSRunLoop currentRunLoop] addTimer: [flasher retain]
										 forMode: NSDefaultRunLoopMode];
		}
	}
}

- (void) setShown: (BOOL) shown {
	if (shown == isShown) return;
	
	isShown = shown;

	[self ZCblunk];
}

- (void) setActive: (BOOL) active {
	if (active == isActive) return;
	
	isActive = active;
	if (!isActive) blink = YES;

	[self ZCblunk];
}

- (void) setFirst: (BOOL) first {
	if (first == isFirst) return;
	
	isFirst = first;
	if (!isFirst) blink = YES;
	
	[self ZCblunk];
}

@end
