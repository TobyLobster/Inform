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
	[cursor release];
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect {
    NSSize fixedSize = [@"M" sizeWithAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [zoomView fontWithStyle:ZFixedStyle], NSFontAttributeName, nil]];
    
    NSEnumerator* upperEnum;
    int ypos = 0;
	float width = [self bounds].size.width;

    upperEnum = [[zoomView upperWindows] objectEnumerator];

    // Draw each window in turn
    ZoomUpperWindow* win;
    while (win = [upperEnum nextObject]) {
        int y;

        // Get the lines from the window
        NSArray* lines = [win lines];

        // Work out how many to draw
        int maxY = [win length];
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

// = Flashing the cursor =

- (NSPoint) cursorPos {
	// NOTE: will break in v3 games that get input in the upper window. Luckily, none exist.
	ZoomUpperWindow* activeWindow = (ZoomUpperWindow*)[zoomView focusedView];
	
	if (![activeWindow isKindOfClass: [ZoomUpperWindow class]]) {
		// Can't update
		return NSMakePoint(0,0);
	}

	NSPoint cp = [activeWindow cursorPosition];
		
    NSSize fixedSize = [@"M" sizeWithAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [zoomView fontWithStyle:ZFixedStyle], NSFontAttributeName, nil]];
	
	return NSMakePoint(cp.x * fixedSize.width, cp.y * fixedSize.height);
}

- (void) updateCursor {
	ZoomUpperWindow* activeWindow = (ZoomUpperWindow*)[zoomView focusedView];
	
	if (![activeWindow isKindOfClass: [ZoomUpperWindow class]]) {
		// Can't update
		return;
	}
	
	// Font size
	NSFont* font = [zoomView fontWithStyle: ZFixedStyle];
    NSSize fixedSize = [@"M" sizeWithAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [zoomView fontWithStyle:ZFixedStyle], NSFontAttributeName, nil]];
	
	// Get the cursor position
	NSPoint cursorPos = [activeWindow cursorPosition];
	int xp = cursorPos.x;
	int yp = cursorPos.y;

    NSEnumerator* upperEnum = [[zoomView upperWindows] objectEnumerator];
	
    ZoomUpperWindow* win;
	int startY = 0;
    while (win = [upperEnum nextObject]) {
		if (win == activeWindow) {
			// Position the cursor
			[cursor positionAt: NSMakePoint(fixedSize.width * xp, fixedSize.height * (yp + startY))
					  withFont: font];
		}
		
		startY += [win length];
	}

	[self setNeedsDisplay: YES];
}

- (void) blinkCursor: (ZoomCursor*) sender {
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

// = Input line =

- (void) activateInputLine {
	ZoomUpperWindow* activeWindow = (ZoomUpperWindow*)[zoomView focusedView];
	
	if (![activeWindow isKindOfClass: [ZoomUpperWindow class]]) {
		// Can't update
		return;
	}

	// FOXME: send input styles over from the server
	ZStyle* style = [activeWindow inputStyle];
	if (style == nil) {
		style = [[ZStyle alloc] init];
		[style autorelease];
		
		[style setFixed: YES];
		[style setReversed: YES];
	}
	
	// Position the input line
	NSDictionary* styleAttributes = [zoomView attributesForStyle: style];

	[cursor positionAt: [self cursorPos]
			  withFont: [zoomView fontWithStyle: ZFixedStyle]];
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

- (void) inputLineHasChanged: (ZoomInputLine*) sender {
	[self setNeedsDisplay: YES];
}

- (void) endOfLineReached: (ZoomInputLine*) sender {
	[zoomView endOfLineReached: sender];
	
	[cursor setShown: NO];
	
	if (sender == inputLine) {
		[inputLine release];
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

// = Updating the cursor =

- (void) windowDidBecomeKey: (NSNotification*) not {
	if (cursor) {
		[cursor setActive: YES];
	}
}

- (void) windowDidResignKey: (NSNotification*) not {
	if (cursor) {
		[cursor setActive: NO];
	}
}

// = Accessibility =


- (NSArray*) accessibilityAttributeNames {
	NSMutableArray* result = [[super accessibilityAttributeNames] mutableCopy];
	
	[result addObjectsFromArray:[NSArray arrayWithObjects: 
								 NSAccessibilityRoleDescriptionAttribute,
								 NSAccessibilityTitleAttribute,
								 nil]];
	
	return [result autorelease];
}

- (id)accessibilityAttributeValue:(NSString *)attribute {
	if ([attribute isEqualToString: NSAccessibilityTitleAttribute]) {
		NSEnumerator* upperEnum = [[zoomView upperWindows] objectEnumerator];
		NSMutableString* status = [NSMutableString string];
		
		ZoomUpperWindow* win;
		while (win = [upperEnum nextObject]) {
			NSArray* lines = [win lines];
			NSEnumerator* linesEnum = [lines objectEnumerator];
			NSMutableAttributedString* lineText;
			while (lineText = [linesEnum nextObject]) {
				[status appendString: [lineText string]];
				[status appendString: @" "];
			}
		}
		
		return status;
	} else if ([attribute isEqualToString: NSAccessibilityRoleDescriptionAttribute]) {
		NSEnumerator* upperEnum = [[zoomView upperWindows] objectEnumerator];
		NSMutableString* status = [NSMutableString string];
		
		ZoomUpperWindow* win;
		while (win = [upperEnum nextObject]) {
			NSArray* lines = [win lines];
			NSEnumerator* linesEnum = [lines objectEnumerator];
			NSMutableAttributedString* lineText;
			while (lineText = [linesEnum nextObject]) {
				[status appendString: [lineText string]];
				[status appendString: @"%@"];
			}
		}

		return [NSString stringWithFormat: @"Status bar"];
	} else if ([attribute isEqualToString: NSAccessibilityParentAttribute]) {
		return zoomView;
	}
	
	return [super accessibilityAttributeValue: attribute];
}

- (BOOL)accessibilityIsIgnored {
	return NO;
}

@end
