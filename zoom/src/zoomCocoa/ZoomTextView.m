//
//  ZoomTextView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import "ZoomTextView.h"
#import "ZoomView.h"
#import "ZoomPreferences.h"
#import <ZoomView/ZoomView-Swift.h>

@implementation ZoomTextView

- (id) initWithFrame: (NSRect) frame {
    self = [super initWithFrame: frame];
    if (self) {
        pastedLines = [[NSMutableArray alloc] init];
		pastedScaleFactor = 1.0;
    }
    return self;
}

// Key event handling

- (void) keyDown: (NSEvent*) event {
    NSView* superview = [self superview];

    while (![superview isKindOfClass: [ZoomView class]]) {
        superview = [superview superview];
        if (superview == nil) break;
    }

    if (![(ZoomView*)superview handleKeyDown: event]) {
        [super keyDown: event];
    }
}

#pragma mark - Mouse event handling

- (void) mouseDown: (NSEvent*) evt {
	if (!dragged) {
		NSView* superview = [self superview];
		
		while (![superview isKindOfClass: [ZoomView class]]) {
			superview = [superview superview];
			if (superview == nil) break;
		}
		
		[(ZoomView*)superview clickAtPointInWindow: [evt locationInWindow]
										 withCount: [evt clickCount]];
	}
	
	[super mouseDown: evt];
}

- (BOOL)isAccessibilityElement {
	if ([[ZoomPreferences globalPreferences] speakGameText]) {
		return NO;
	}
	return [super isAccessibilityElement];
}

#pragma mark - Drawing

// (Draw the overlays)
- (void) drawRect: (NSRect) r {
	// Perform standard text drawing actions (we save state so that we don't get the text view clip rectangle at the end)
	[[NSGraphicsContext currentContext] saveGraphicsState];	
    [super drawRect: r];
	[[NSGraphicsContext currentContext] restoreGraphicsState];

    NSRect ourBounds = [self bounds];
    NSRect superBounds = [[self superview] frame];
	
	superBounds = [self convertRect: superBounds
						   fromView: [self superview]];

    // The enclosing ZoomView
    NSView* superview = [self superview];

    while (![superview isKindOfClass: [ZoomView class]]) {
        superview = [superview superview];
        if (superview == nil) break;
    }
    ZoomView* zoomView = (ZoomView*) superview;

    CGFloat offset = [zoomView upperBufferHeight]/pastedScaleFactor;
    
    // Draw pasted lines
	NSAffineTransform* invertTransform = [NSAffineTransform transform];
	[invertTransform scaleXBy: 1.0 
						  yBy: -1.0];

	NSAffineTransform* scaleTransform = [NSAffineTransform transform];
	[scaleTransform scaleXBy: pastedScaleFactor
						 yBy: pastedScaleFactor];
	
    for (NSArray* line in pastedLines) {
        NSValue* rect = [line objectAtIndex: 0];
        NSRect   lineRect = [rect rectValue];

        lineRect.origin.y -= offset;
		NSRect nonScaledRect = lineRect;
		
		lineRect.origin.x *= pastedScaleFactor;
		lineRect.origin.y *= pastedScaleFactor;
		lineRect.size.width *= pastedScaleFactor;
		lineRect.size.height *= pastedScaleFactor;
		
		lineRect.origin.x = floor(lineRect.origin.x+0.5);
		lineRect.origin.y = floor(lineRect.origin.y+0.5);
		lineRect.size.width = floor(lineRect.size.width+0.5);
		lineRect.size.height = floor(lineRect.size.height+0.5);
		
        if (NSIntersectsRect(r, lineRect)) {
            NSAttributedString* str = [line objectAtIndex: 1];
			
            if (NSMaxY(lineRect) < NSMaxY(ourBounds)-superBounds.size.height) {
                // Draw it faded out (so text underneath becomes increasingly visible)
                NSImage* fadeImage;

                CGFloat fadeAmount = (NSMaxY(ourBounds)-superBounds.size.height) - NSMaxY(lineRect);
                fadeAmount /= 2048;
                fadeAmount += 0.25;
                if (fadeAmount > 0.75) fadeAmount = 0.75;
                fadeAmount = 1-fadeAmount;
                
                fadeImage = [[NSImage alloc] initWithSize: lineRect.size];

                [fadeImage setSize: lineRect.size];
                [fadeImage lockFocusFlipped:NO];

				[[NSGraphicsContext currentContext] saveGraphicsState];					

				// Because text views are drawn flipped, we need to draw the image upsidedown
				[scaleTransform concat];
				[invertTransform concat];
                
				[str drawAtPoint: NSMakePoint(0, -lineRect.size.height/pastedScaleFactor)];
				[[NSGraphicsContext currentContext] restoreGraphicsState];
                [fadeImage unlockFocus];

				[fadeImage drawInRect:NSMakeRect(lineRect.origin.x,
												 lineRect.origin.y,
												 lineRect.size.width,
												 lineRect.size.height)
							 fromRect:NSMakeRect(0,0,
												 lineRect.size.width,
												 lineRect.size.height)
							operation:NSCompositingOperationSourceOver
							 fraction:fadeAmount];
            } else {
				[[NSGraphicsContext currentContext] saveGraphicsState];	
				[scaleTransform concat];
                [str drawAtPoint: nonScaledRect.origin];
				[[NSGraphicsContext currentContext] restoreGraphicsState];
            }
        }
    }
}

#pragma mark - Pasting overlays

// Things that are drawn in the upper window, but outside the point at which it has been split are
// overlaid into the text view.

- (void) clearPastedLines {
    [pastedLines removeAllObjects];
}

@synthesize pastedLineScaleFactor=pastedScaleFactor;

- (void) pasteUpperWindowLinesFromZoomWindow: (ZoomUpperWindow*) win {
    NSArray* lines = [win lines];
    BOOL changed;
    
    if ([lines count] < [win length]) {
        return; // Nothing to do
    }

    // Get some information about the view
    NSView* container = (NSView*)[self superview];

    // The container
    while (![container isKindOfClass: [NSClipView class]]) {
        container = [container superview];
        if (container == nil) break;
    }

    if (container == nil) container = self;

    // The enclosing ZoomView
    NSView* superview = [self superview];

    while (![superview isKindOfClass: [ZoomView class]]) {
        superview = [superview superview];
        if (superview == nil) break;
    }
    ZoomView* zoomView = (ZoomView*) superview;
    
    NSRect ourBounds = [self bounds];
    NSRect containerBounds = [container bounds];
	
	//ourBounds = [self convertRect: ourBounds toView: container];
	containerBounds = [self convertRect: containerBounds fromView: container];

    CGFloat offset = [zoomView upperBufferHeight];

    CGFloat topPoint = NSMaxY(ourBounds) - containerBounds.size.height;
    
    NSSize fixedSize = [@"M" sizeWithAttributes:
                        @{NSFontAttributeName: [zoomView fontFromStyle:ZFontStyleFixed]}];
    
	NSFontManager* fm = [NSFontManager sharedFontManager];
	
    // Perform the pasting
    changed = NO;

    NSRect drawRect = NSZeroRect;
    
    NSInteger l;
    for (l=[win length]; l<[lines count]; l++) {
        NSRect r;
        NSAttributedString* str = [lines objectAtIndex: l];

        if ([str length] > 0) {
            r = NSMakeRect(0, topPoint+fixedSize.height*(l-[win length]), 0,0);
            r.origin.y += offset;
            r.size = [str size];
			
			// Scale down the rectangle by the scale factor
			if (pastedScaleFactor != 1.0) {
				r.origin.x /= pastedScaleFactor;
				r.origin.y /= pastedScaleFactor;
				r.size.width /= pastedScaleFactor;
				r.size.height /= pastedScaleFactor;

				// Scale down the font size by the scale factor
				NSMutableAttributedString* editedStr = [str mutableCopy];
				
				NSRange editRange;
				NSDictionary* currentAttributes = [editedStr attributesAtIndex: 0
																effectiveRange: &editRange];
				for (;;) {
					NSFont* oldFont = [currentAttributes objectForKey: NSFontAttributeName];
					
					if (oldFont != nil) {
						NSFont* newFont = [fm convertFont: oldFont
												   toSize: [oldFont pointSize] / pastedScaleFactor];
						[editedStr addAttribute: NSFontAttributeName
										  value: newFont
										  range: editRange];
					}
					
					NSInteger newPos = editRange.location + editRange.length;
					if (editRange.length == 0) newPos++;
					if (newPos >= [editedStr length]) break;
					
					currentAttributes = [editedStr attributesAtIndex: newPos
													  effectiveRange: &editRange];
				}
				
				str = editedStr;
			}
			
			// Add this line to the set of pasted lines
            [pastedLines addObject: @[@(r),
                                      str]];

            r.origin.y -= offset;

            drawRect = NSUnionRect(drawRect, r);
            changed = YES;
        }
    }

    if (changed) {
        // Update the window
        [self setNeedsDisplayInRect: drawRect];
    }

    // Scrub the lines
    [win cutLines];
}

- (void) offsetPastedLines: (CGFloat) offset {
	if (offset == 0) return;
	offset /= pastedScaleFactor;
	
	// Subtract offset from all of the pasted lines, and remove any that have disappeared
	NSMutableArray* newLines = [[NSMutableArray alloc] init];
	
	for (NSArray* line in pastedLines) {
		// Work out the new position of this line
		NSRect lineRect = [[line objectAtIndex: 0] rectValue];
		NSAttributedString* str = [line objectAtIndex: 1];
		
		lineRect.origin.y -= offset;

		// If it's still in the view, then add it to the modified array
		if (NSMaxY(lineRect) > 0) {
			[newLines addObject: @[
				@(lineRect),
				str]];
		}
	}
	
	// Replace the pasted lines with the new set of lines
	pastedLines = newLines;
}

- (id)accessibilityParent {
	NSView* parent = [self superview];
	while (parent != nil && ![parent isKindOfClass: [ZoomView class]]) {
		parent = [parent superview];
	}
	if (parent) return parent;
	return [super accessibilityParent];
}

@end
