//
//  IFSourceFileView.m
//  Inform
//
//  Created by Andrew Hunter on Mon Feb 16 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFSourceFileView.h"
#import "IFProjectController.h"
#import "IFSourcePage.h"

static NSImage* topTear			= nil;
static NSImage* bottomTear		= nil;
static NSImage* arrowNotPressed = nil;

@implementation IFSourceFileView {
    /// \c YES if we should draw a 'tear' at the top of the view
    BOOL tornAtTop;
    /// \c YES if we should draw a 'tear' at the bottom of the view
    BOOL tornAtBottom;
    /// The last known 'used' rect (used to determine whether or not to update the bottom tear)
    NSRect lastUsedRect;
}

- (void) loadImages {
	if (!topTear)			topTear			= [NSImage imageNamed: @"App/TornPages/torn_top"];
	if (!bottomTear)		bottomTear		= [NSImage imageNamed: @"App/TornPages/torn_bottom"];
	
	if (!arrowNotPressed)	arrowNotPressed = [NSImage imageNamed: @"App/TornPages/TearArrow"];
}

- (void) keyDown: (NSEvent*) event {
	IFProjectController* controller = self.window.windowController;
	if ([controller isKindOfClass: [IFProjectController class]]) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(removeAllTemporaryHighlights)
											 target: controller
										   argument: nil
											  order: 8
											  modes: @[NSDefaultRunLoopMode]];
	}

	[super keyDown: event];
}

- (NSTouchBar *)makeTouchBar {
  return nil;
}

- (void) mouseDown: (NSEvent*) event {
	NSEventModifierFlags modifiers = event.modifierFlags;
	
	if ((modifiers & (NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand)) == 0
		&& event.clickCount == 1) {
		// Single click, no modifiers
		NSRect bounds = self.bounds;
		NSRect usedRect = [self.layoutManager usedRectForTextContainer: self.textContainer];
		NSPoint mousePoint = [self convertPoint: event.locationInWindow
									   fromView: nil];

        id<NSTextViewDelegate> tempDeleg = self.delegate;
        id<IFSourceNavigation> deleg = nil;
        if ([tempDeleg conformsToProtocol:@protocol(IFSourceNavigation)])
        {
            deleg = (id<IFSourceNavigation>) self.delegate;
        }
        if ((tornAtTop && mousePoint.y < NSMinY(bounds)+topTear.size.height)) {
            [deleg sourceFileShowPreviousSection: self];

            return;
        } else if (tornAtBottom && mousePoint.y > NSMinY(bounds)+self.textContainerOrigin.y+NSMaxY(usedRect)) {
            [deleg sourceFileShowNextSection: self];

			// Finished handling this event
			return;
		}
	}
	
	// Process this event as normal
	[super mouseDown: event];
}

-(bool) setMouseCursorWithPosition:(NSPoint) mousePoint {
    mousePoint = [self convertPoint: mousePoint
                           fromView: nil];
    if( tornAtTop ) {
        NSRect bounds = self.bounds;
        NSRect tornAtTopRect = NSMakeRect(NSMinX(bounds), NSMinY(bounds), bounds.size.width, topTear.size.height);
        
        if( NSPointInRect(mousePoint, tornAtTopRect) ) {
            [[NSCursor pointingHandCursor] set];
            return true;
        }
    }
    
    if( tornAtBottom ) {
        NSPoint origin = self.textContainerOrigin;
        NSRect bounds = self.bounds;
        NSRect usedRect = [self.layoutManager usedRectForTextContainer: self.textContainer];
        NSSize containerSize = NSMakeSize(NSMaxX(usedRect), NSMaxY(usedRect));
        
        NSRect tornAtBottomRect = NSMakeRect(NSMinX(bounds),
                                             origin.y + containerSize.height,
                                             bounds.size.width,
                                             bounds.size.height - (origin.y + containerSize.height));
        if( NSPointInRect(mousePoint, tornAtBottomRect) ) {
            [[NSCursor pointingHandCursor] set];
            return true;
        }
    }
    return false;
}

-(void) mouseMoved:(NSEvent *)theEvent {
    if( ![self setMouseCursorWithPosition:theEvent.locationInWindow] ) {
        [super mouseMoved:theEvent];
    }
}

#pragma mark - Drawing

- (void) drawRect: (NSRect) rect {
	// Perform normal drawing
	[[NSGraphicsContext currentContext] saveGraphicsState];
	[super drawRect: rect];
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	// Draw the 'page tears' if necessary
	NSRect bounds = self.bounds;
	NSColor* tearColour = [NSColor colorWithDeviceRed: 0.95
												green: 0.95
												 blue: 0.9
												alpha: 1.0];

	if (tornAtTop) {
		NSSize tornSize = topTear.size;
		
		// Draw the tear
		[topTear drawInRect: NSMakeRect(NSMinX(bounds), NSMinY(bounds), bounds.size.width, tornSize.height)
				   fromRect: NSMakeRect(0,0, bounds.size.width, tornSize.height)
				  operation: NSCompositingOperationSourceOver
				   fraction: 1.0
             respectFlipped: YES
                      hints: nil];
		
		// Draw the 'up' arrow
		NSImage* arrow = arrowNotPressed;
		NSSize upSize = arrowNotPressed.size;
		NSRect upRect;
		
		upRect.origin	= NSMakePoint(floor(NSMinX(bounds) + (bounds.size.width - upSize.width)/2),
                                      floor(NSMinY(bounds) + (tornSize.height - upSize.height)/2));
		upRect.size		= upSize;
		
		[arrow drawInRect: upRect
				 fromRect: NSZeroRect
				operation: NSCompositingOperationSourceOver
                 fraction: 1.0
           respectFlipped: YES
                    hints: nil];
	}
	if (tornAtBottom) {
		NSSize tornSize = bottomTear.size;
		NSPoint origin = self.textContainerOrigin;
		NSRect usedRect = [self.layoutManager usedRectForTextContainer: self.textContainer];
		NSSize containerSize = NSMakeSize(NSMaxX(usedRect), NSMaxY(usedRect));
		
		// Draw the background
		[tearColour set];
		NSRectFill(NSMakeRect(NSMinX(bounds),
                              origin.y + containerSize.height + tornSize.height,
                              bounds.size.width,
                              bounds.size.height - (origin.y + containerSize.height + tornSize.height)));
		
		// Draw the tear
		[bottomTear drawInRect: NSMakeRect(NSMinX(bounds), origin.y + containerSize.height, bounds.size.width, tornSize.height)
					  fromRect: NSMakeRect(0,0, bounds.size.width, tornSize.height)
					 operation: NSCompositingOperationSourceOver
                      fraction: 1.0
                respectFlipped: YES
                         hints: nil];

		// Draw the 'down' arrow
		NSImage* arrow = arrowNotPressed;
		NSSize upSize = arrowNotPressed.size;
		NSRect upRect;
		
		upRect.origin	= NSMakePoint(floor(NSMinX(bounds) + (bounds.size.width - upSize.width)/2),
                                      (origin.y + containerSize.height + (tornSize.height - upSize.height)/2));
		upRect.size		= upSize;
		
		[arrow drawInRect: upRect
				 fromRect: NSZeroRect
				operation: NSCompositingOperationSourceOver
                 fraction: 1.0
           respectFlipped: NO
                    hints: nil];
	}
}

#pragma mark - Drawing 'tears' at the top and bottom

- (void) updateTearing {
	// Load the images if they aren't already available
	[self loadImages];

	// Work out the inset to use
	NSSize inset = NSMakeSize(3,6);
	
	if (tornAtTop) {
		inset.height += floor(topTear.size.height);
	}
	if (tornAtBottom) {
		inset.height += floor(bottomTear.size.height);
	}
	inset.height = floor(inset.height/2);

	// Update the display
	self.textContainerInset = inset;
	
	lastUsedRect = [self.layoutManager usedRectForTextContainer: self.textContainer];
	[self setNeedsDisplay: YES];
}

- (BOOL) checkForRedraw {
	if (tornAtBottom) {
		// If the last used rect is different from the current used rect, then redraw the bottom of the display as well
		NSRect newUsedRect = [self.layoutManager usedRectForTextContainer: self.textContainer];
		
		if (NSMaxY(newUsedRect) != NSMaxY(lastUsedRect)) {
			NSRect bounds = self.bounds;
			lastUsedRect = newUsedRect;
			
            CGFloat minY = NSMinY(lastUsedRect);
			
			NSRect needsDisplay = NSMakeRect(NSMinX(bounds), minY, bounds.size.width, NSMaxY(bounds)-minY);
			[super setNeedsDisplayInRect: needsDisplay];
			
			return YES;
		}
	}
	
	return NO;
}

- (void)setNeedsDisplayInRect: (NSRect)invalidRect {
	[super setNeedsDisplayInRect: invalidRect];
	[self checkForRedraw];
}

- (NSPoint) textContainerOrigin {
	// Calculate the origin
	NSPoint origin = NSMakePoint(3,6);
	
	if (tornAtTop) {
		origin.y += topTear.size.height;
	}
	
	return origin;
}

- (void) setTornAtTop: (BOOL) newTornAtTop {
	if (tornAtTop != newTornAtTop) {
		tornAtTop = newTornAtTop;
		[self updateTearing];
	}
}

- (void) setTornAtBottom: (BOOL) newTornAtBottom {
	if (tornAtBottom != newTornAtBottom) {
		tornAtBottom = newTornAtBottom;
		[self updateTearing];
	}
}

//
// Paste (and dropped text, and services)
//
- (BOOL) readSelectionFromPasteboard: (NSPasteboard*) pboard
                                type: (NSPasteboardType) type {
    // Plain text, which NSTextView asks for by its old name
    if ([type isEqualToString: NSPasteboardTypeString] || [type isEqualToString: @"NSStringPboardType"]) {
        NSString* string = [pboard stringForType: NSPasteboardTypeString];

        // Fix line endings
        if (string != nil && [string rangeOfString: @"\r"].location != NSNotFound) {
            string = [string stringByReplacingOccurrencesOfString: @"\r\n" withString: @"\n"];
            string = [string stringByReplacingOccurrencesOfString: @"\r" withString: @"\n"];

            // Read the fixed text instead, as from the pasteboard
            NSPasteboard* fixed = [NSPasteboard pasteboardWithUniqueName];
            [fixed declareTypes: @[NSPasteboardTypeString] owner: nil];
            [fixed setString: string forType: NSPasteboardTypeString];
            BOOL result = [super readSelectionFromPasteboard: fixed type: type];
            [fixed releaseGlobally];
            return result;
        }
    }

    return [super readSelectionFromPasteboard: pboard type: type];
}

@end
