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

#pragma mark - Initialisation

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
		
		lastVisible = [self isVisible];
		lastActive = [self activeStyle];
	}
	
	return self;
}

- (void) dealloc {
	if (flasher) {
		[flasher invalidate];
	}
}

#pragma mark - Delegate

@synthesize delegate;

#pragma mark - Blinking

+ (NSSet<NSString *> *)keyPathsForValuesAffectingVisible
{
	return [NSSet setWithObjects:@"shown", @"blinking", @"blink", nil];
}

- (BOOL) isVisible {
	return (isShown&&(!isBlinking||blink));
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingActiveStyle
{
	return [NSSet setWithObjects:@"active", @"first", nil];
}

- (BOOL) activeStyle {
	return (isActive&&isFirst);
}

- (void) ZCblunk {
	// Cursor has, uh, blunked
	
	// Only send the message if our visibility has changed
	BOOL nowVisible = self.visible;
	BOOL nowActive = [self activeStyle];
	if (nowActive == lastActive &&
		nowVisible == lastVisible) {
		return;
	}

	lastVisible = nowVisible;
	lastActive = nowActive;

	// Notify the delegate that we have blinked
	if ([delegate respondsToSelector: @selector(blinkCursor:)]) {
		[delegate blinkCursor: self];
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

#pragma mark - Drawing

- (void) draw {
	if (!self.visible) return;

	// Cursor colour
	[[[NSColor controlAccentColor] colorWithAlphaComponent:0.6] set];
	
	// Draw the cursor
	if ([self activeStyle]) {
		[NSBezierPath strokeRect: cursorRect];
		[NSBezierPath fillRect: cursorRect];
	} else {
		[NSBezierPath strokeRect: cursorRect];
	}
}

#pragma mark - Positioning

- (NSSize) sizeOfFont: (NSFont*) font {
    // Hack: require a layout manager for OS X 10.6, but we don't have the entire text system to fall back on
    NSLayoutManager* layoutManager = [[NSLayoutManager alloc] init];
    
    // Width is one 'en'
	CGFloat width = [@"n" sizeWithAttributes: @{NSFontAttributeName: font}].width;
    
    // Height is decided by the layout manager
    CGFloat height = [layoutManager defaultLineHeightForFont: font];
    
    return NSMakeSize(width, height);
}

- (void) positionAt: (NSPoint) pt
		   withFont: (NSFont*) font {
	// Cause the delegate to undraw any previous cursor
	BOOL wasShown = isShown;
	isShown = NO;
	[self ZCblunk];
	
	// Move the cursor
    NSSize fontSize = [self sizeOfFont: font];
		
	cursorRect = NSMakeRect(pt.x, pt.y, fontSize.width, fontSize.height);
	
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
		 atCharacterIndex: (NSInteger) index {
	// Cause the delegate to undraw any previous cursor
	BOOL wasShown = isShown;
	isShown = NO;
	[self ZCblunk];
	
	NSFont* font = [attributes objectForKey: NSFontAttributeName];
	
	// Move the cursor
    NSSize fontSize = [self sizeOfFont: font];
	CGFloat offset = [[string substringToIndex: index] sizeWithAttributes: attributes].width;
	
	cursorRect = NSMakeRect(cursorPos.x+offset, cursorPos.y, fontSize.width, fontSize.height);

	// Redraw
	isShown = wasShown;
	blink = YES;
	[self ZCblunk];
}

- (NSRect) cursorRect {
	return NSInsetRect(cursorRect, -2.0, -2.0);
}

#pragma mark - Display status

@synthesize blinking = isBlinking;
- (void) setBlinking: (BOOL) blnk {
	if (blnk == isBlinking) return;
	
	isBlinking = blnk;
	
	if (blnk == NO) {
		blink = YES;
		[self ZCblunk];
		
		if (flasher) {
			[flasher invalidate];
			flasher = nil;
		}
	} else {
		if (!flasher) {
			flasher = [NSTimer timerWithTimeInterval: BlinkInterval
											  target: self
											selector: @selector(ZCblinky)
											userInfo: nil
											 repeats: YES];
			[[NSRunLoop currentRunLoop] addTimer: flasher
										 forMode: NSDefaultRunLoopMode];
		}
	}
}

@synthesize shown = isShown;
- (void) setShown: (BOOL) shown {
	if (shown == isShown) return;
	
	isShown = shown;

	[self ZCblunk];
}

@synthesize active = isActive;
- (void) setActive: (BOOL) active {
	if (active == isActive) return;
	
	isActive = active;
	if (!isActive) blink = YES;

	[self ZCblunk];
}

@synthesize first = isFirst;
- (void) setFirst: (BOOL) first {
	if (first == isFirst) return;
	
	isFirst = first;
	if (!isFirst) blink = YES;
	
	[self ZCblunk];
}

@end
