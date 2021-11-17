//
//  ZoomUpperWindowView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Oct 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomUpperWindowView.h"
#import "ZoomUpperWindow.h"

@implementation ZoomUpperWindowView

- (id)initWithFrame:(NSRect)frame
           zoomView:(ZoomView*) view {
    self = [super initWithFrame:frame];
    if (self) {
        zoomView = view;
		
		cursor = [[ZoomCursor alloc] init];
		[cursor setDelegate: self];
		
		[cursor setShown: NO];
    }
    return self;
}

- (void) dealloc {
	[cursor setDelegate: nil];
}

- (void)drawRect:(NSRect)rect {
    NSSize fixedSize = [@"M" sizeWithAttributes:
						@{NSFontAttributeName: [zoomView fontFromStyle:ZFontStyleFixed]}];
    
    int ypos = 0;
	CGFloat width = [self bounds].size.width;

    // Draw each window in turn
    for (ZoomUpperWindow* win in [zoomView upperWindows]) {
        NSInteger y;

        // Get the lines from the window
        NSArray* lines = [win lines];

        // Work out how many to draw
        NSInteger maxY = [win length];
        if (maxY > [lines count]) maxY = [lines count];

        // Fill in the background
        NSRect winRect = NSMakeRect(0,
                                    ypos*fixedSize.height,
                                    rect.size.width,
                                    (ypos+[win length])*fixedSize.height);
        [[win backgroundColour] set];
        NSRectFill(winRect);
        
        // Draw 'em
        for (y=0; y<maxY; y++) {
            NSMutableAttributedString* line = [lines objectAtIndex: y];

			// Only draw the lines that we actually need to draw: keeps the processor usage down when
			// flashing the cursor
			if (NSIntersectsRect(rect, NSMakeRect(0, fixedSize.height * (ypos+y), width, fixedSize.height))) {
				[line drawAtPoint: NSMakePoint(0, fixedSize.height*(ypos+y))];
			}
        }
        
        ypos += [win length];
    }
	
	// Draw the cursor
	if (inputLine) {
		[inputLine drawAtPoint: inputLinePos];
	}
	
	[cursor draw];
}

- (BOOL) isFlipped {
    return YES;
}

#pragma mark - Flashing the cursor

- (NSPoint) cursorPos {
	// NOTE: will break in v3 games that get input in the upper window. Luckily, none exist.
	ZoomUpperWindow* activeWindow = (ZoomUpperWindow*)[zoomView focusedView];
	
	if (![activeWindow isKindOfClass: [ZoomUpperWindow class]]) {
		// Can't update
		return NSMakePoint(0,0);
	}

	NSPoint cp = [activeWindow cursorPosition];
		
    NSSize fixedSize = [@"M" sizeWithAttributes:
						@{NSFontAttributeName: [zoomView fontFromStyle:ZFontStyleFixed]}];
	
	return NSMakePoint(cp.x * fixedSize.width, cp.y * fixedSize.height);
}

- (void) updateCursor {
	ZoomUpperWindow* activeWindow = (ZoomUpperWindow*)[zoomView focusedView];
	
	if (![activeWindow isKindOfClass: [ZoomUpperWindow class]]) {
		// Can't update
		return;
	}
	
	// Font size
	NSFont* font = [zoomView fontFromStyle: ZFontStyleFixed];
    NSSize fixedSize = [@"M" sizeWithAttributes:
						@{NSFontAttributeName: font}];
	
	// Get the cursor position
	NSPoint cursorPos = [activeWindow cursorPosition];
	int xp = cursorPos.x;
	int yp = cursorPos.y;

	int startY = 0;
    for (ZoomUpperWindow* win in zoomView.upperWindows) {
		if (win == activeWindow) {
			// Position the cursor
			[cursor positionAt: NSMakePoint(fixedSize.width * xp, fixedSize.height * (yp + startY))
					  withFont: font];
		}
		
		startY += [win length];
	}

	[self setNeedsDisplay: YES];
}

- (void) blinkCursor: (__unused ZoomCursor*) sender {
	// Draw the cursor
	[self setNeedsDisplay: YES];
	// [self setNeedsDisplayInRect: [cursor cursorRect]]; -- FAILS, for some reason the window does not get redrawn correctly
}

- (void) setFlashCursor: (BOOL) flash {
	[cursor setShown: flash];
	[cursor setBlinking: flash];
	
	[self updateCursor];
	
}

- (void) mouseUp: (NSEvent*) evt {
	[zoomView clickAtPointInWindow: [evt locationInWindow]
						 withCount: [evt clickCount]];
	
	[super mouseUp: evt];
}

#pragma mark - Input line

- (void) activateInputLine {
	ZoomUpperWindow* activeWindow = (ZoomUpperWindow*)[zoomView focusedView];
	
	if (![activeWindow isKindOfClass: [ZoomUpperWindow class]]) {
		// Can't update
		return;
	}

	// FIXME: send input styles over from the server
	ZStyle* style = [activeWindow inputStyle];
	if (style == nil) {
		style = [[ZStyle alloc] init];
		
		[style setFixed: YES];
		[style setReversed: YES];
	}
	
	// Position the input line
	NSDictionary* styleAttributes = [zoomView attributesForStyle: style];

	[cursor positionAt: [self cursorPos]
			  withFont: [zoomView fontFromStyle: ZFontStyleFixed]];
	inputLinePos = [self cursorPos];
	inputLinePos.y -= [[styleAttributes objectForKey: NSFontAttributeName] descender];
	
	if (!inputLine) {
		inputLine = [[ZoomInputLine alloc] initWithCursor: cursor
											   attributes: [zoomView attributesForStyle: style]];
	}
	
	// Start receiving input
	[inputLine setDelegate: self];
	[cursor setShown: YES];
	[cursor setBlinking: YES];
	
	[self setNeedsDisplay: YES];
}

- (void) inputLineHasChanged: (__unused ZoomInputLine*) sender {
	[self setNeedsDisplay: YES];
}

- (void) endOfLineReached: (ZoomInputLine*) sender {
	[zoomView endOfLineReached: sender];
	
	[cursor setShown: NO];
	
	if (sender == inputLine) {
		inputLine = nil;
	}
}

- (NSString*) lastHistoryItem {
	return [zoomView lastHistoryItem];
}

- (NSString*) nextHistoryItem {
	return [zoomView nextHistoryItem];
}

- (void) keyDown: (NSEvent*) evt {
	if (![zoomView handleKeyDown: evt]) {
		[inputLine keyDown: evt];
	}
}

- (BOOL) acceptsFirstResponder {
	return inputLine != nil;
}

#pragma mark - Updating the cursor

- (void) windowDidBecomeKey: (__unused NSNotification*) not {
	if (cursor) {
		[cursor setActive: YES];
	}
}

- (void) windowDidResignKey: (__unused NSNotification*) not {
	if (cursor) {
		[cursor setActive: NO];
	}
}

#pragma mark - Accessibility

- (NSString *)accessibilityValue
{
	NSMutableString* status = [NSMutableString string];
	
	for (ZoomUpperWindow* win in [zoomView upperWindows]) {
		for (NSMutableAttributedString* lineText in [win lines]) {
			[status appendString: [lineText string]];
			[status appendString: @" "];
		}
	}
	
	return [status copy];
}

- (NSString *)accessibilityRoleDescription {
	return @"Status bar";
}

- (id)accessibilityParent
{
	return zoomView;
}

- (BOOL)isAccessibilityElement {
	return YES;
}

@end
