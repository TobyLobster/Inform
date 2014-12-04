//
//  IFTranscriptView.m
//  Inform
//
//  Created by Andrew Hunter on 12/09/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFTranscriptView.h"
#import "IFImageCache.h"

@implementation IFTranscriptView

static NSLayoutManager *layoutManager = nil;

// = Initialisation =

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    
	if (self) {
		layout = [[IFTranscriptLayout alloc] init];
		
		[layout setDelegate: self];
		[layout setWidth: floorf([self bounds].size.width)];

        if( !layoutManager ) {
            layoutManager = [[NSLayoutManager alloc] init];
        }
        else {
            [layoutManager retain];
        }
    }
	
    return self;
}

- (void) dealloc {
	[layout setDelegate: nil];
	[layout release]; layout = nil;
    [layoutManager release]; layoutManager = nil;
	
	[super dealloc];
}

// = Retrieving the layout =

- (IFTranscriptLayout*) transcriptLayout {
	return layout;
}

// = Drawing =

- (BOOL) isFlipped { return YES; }

- (void) setFrame: (NSRect) bounds {
	[super setFrame: bounds];
	
	[layout setWidth: floorf([self bounds].size.width)];
}

- (void)drawRect:(NSRect)rect {
	NSRect bounds = [self bounds];
	
	// Button images
	NSImage* bless       = [IFImageCache loadResourceImage: @"App/Transcript/Bless.png"];
	NSImage* playToHere  = [IFImageCache loadResourceImage: @"App/Transcript/PlayToHere.png"];
	NSImage* showSkein   = [IFImageCache loadResourceImage: @"App/Transcript/ShowSkein.png"];

	NSImage* blessD      = [IFImageCache loadResourceImage: @"App/Transcript/BlessD.png"];
	NSImage* playToHereD = [IFImageCache loadResourceImage: @"App/Transcript/PlayToHereD.png"];
	NSImage* showSkeinD  = [IFImageCache loadResourceImage: @"App/Transcript/ShowSkeinD.png"];
	
	[bless setFlipped: YES];
	[playToHere setFlipped: YES];
	[showSkein setFlipped: YES];
	[blessD setFlipped: YES];
	[playToHereD setFlipped: YES];
	[showSkeinD setFlipped: YES];
	    
	NSSize imgSize = [bless size];							// We assume all these images are the same size
	NSRect imgRect;
	
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = imgSize;

	// Begin the layout if we need to
	if ([layout needsLayout]) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(startLayout)
											 target: layout
										   argument: nil
											  order: 128
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
	}
	
	// Get the items we need to draw
	NSArray* items = [layout itemsInRect: rect];
	
	// Draw them
	for(IFTranscriptItem* item in items) {
		// Draw the item
		float ypos = NSMinY(bounds) + [item offset];
		
		[item drawAtPoint: NSMakePoint(NSMinX(bounds), ypos)
			  highlighted: item==highlightedItem
				   active: item==activeItem];
		
		// Draw the buttons for the item
		NSFont* font = [[item attributes] objectForKey: NSFontAttributeName];
		float fontHeight = [layoutManager defaultLineHeightForFont:font];
		float itemHeight = [item height];
		float textHeight = floorf(itemHeight - fontHeight*2.0);

		float commandButtonY = floorf(ypos + fontHeight*0.75 - imgSize.height/2.0);
		
		if (item == clickedItem && clickedButton == IFTranscriptButtonShowKnot) {
			[showSkeinD drawAtPoint: NSMakePoint(floorf(NSMaxX(bounds) - imgSize.width), commandButtonY)
						  fromRect: imgRect
						 operation: NSCompositeSourceOver
						  fraction: 1.0];
		} else {
			[showSkein drawAtPoint: NSMakePoint(floorf(NSMaxX(bounds) - imgSize.width), commandButtonY)
						  fromRect: imgRect
						 operation: NSCompositeSourceOver
						  fraction: 1.0];
		}
		
		if (item == clickedItem && clickedButton == IFTranscriptButtonPlayToHere) {
			[playToHereD drawAtPoint: NSMakePoint(floorf(NSMaxX(bounds) - imgSize.width*2.0), commandButtonY)
							fromRect: imgRect
						   operation: NSCompositeSourceOver
							fraction: 1.0];
		} else {
			[playToHere drawAtPoint: NSMakePoint(floorf(NSMaxX(bounds) - imgSize.width*2.0), commandButtonY)
						   fromRect: imgRect
						  operation: NSCompositeSourceOver
						   fraction: 1.0];
		}
		
		if (item == clickedItem && clickedButton == IFTranscriptButtonBless) {
			[blessD drawAtPoint: NSMakePoint(floorf(NSMinX(bounds)+((bounds.size.width-imgSize.width)/2.0)), floorf(ypos + (textHeight-imgSize.height)/2.0 + fontHeight*1.75))
					   fromRect: imgRect
					  operation: NSCompositeSourceOver
					   fraction: 1.0];
		} else {
			[bless drawAtPoint: NSMakePoint(floorf(NSMinX(bounds)+((bounds.size.width-imgSize.width)/2.0)), floorf(ypos + (textHeight-imgSize.height)/2.0 + fontHeight*1.75))
					  fromRect: imgRect
					 operation: NSCompositeSourceOver
					  fraction: 1.0];
		}
	}
}

- (void) transcriptHasUpdatedItems: (NSRange) itemRange {
	// FIXME: only draw items as needed, resize the view to fit the items
	
	// Start the layout if necessary (avoids flicker sometimes)
	if ([layout needsLayout]) [layout startLayout];

	// Set our frame appropriately if we need to
	NSRect ourBounds = [self frame];
	ourBounds.size.height = [layout height];
	if (ourBounds.size.height <= 12) ourBounds.size.height = 12;
	[self setFrame: ourBounds];

	// Redraw the items
	[self setNeedsDisplay: YES];
	
	// Cursor rects have probably changed
	[[self window] invalidateCursorRectsForView: self];
}

// = Mousing around =

- (void) mouseDown: (NSEvent*) evt {
	NSRect bounds = [self bounds];
	NSPoint viewPos = [self convertPoint: [evt locationInWindow]
								fromView: nil];

	// Work out which item was clicked (if any)
	NSArray* clickItems = [layout itemsInRect: NSMakeRect(viewPos.x - NSMinX(bounds), viewPos.y - NSMinY(bounds), 1, 1)];
	
	IFTranscriptItem* item = nil;
	if ([clickItems count] > 0) item = [clickItems objectAtIndex: 0];
	
	// Get some item metrics
	float itemTextHeight = [item textHeight];
    NSFont *font = [[item attributes] objectForKey: NSFontAttributeName];
	float fontHeight = [layoutManager defaultLineHeightForFont:font];

	float itemOffset = [item offset];
	NSPoint itemPos = NSMakePoint(viewPos.x - NSMinX(bounds), viewPos.y - NSMinY(bounds) - itemOffset);
	
	// Clicking a button activates that button
	NSSize buttonSize = [(NSImage*)[IFImageCache loadResourceImage: @"App/Transcript/Bless.png"] size];
	NSRect blessButton, playButton, knotButton;
	
	float ypos = NSMinY(bounds) + itemOffset;
	float commandButtonY = floorf(ypos + fontHeight*0.75 - buttonSize.height/2.0);
	
	// Positions of the buttons
	blessButton.origin = NSMakePoint(floorf(NSMinX(bounds)+((bounds.size.width-buttonSize.width)/2.0)), floorf(ypos + (itemTextHeight-buttonSize.height)/2.0 + fontHeight*1.75));
	playButton.origin = NSMakePoint(floorf(NSMaxX(bounds) - buttonSize.width*2.0), commandButtonY);
	knotButton.origin = NSMakePoint(floorf(NSMaxX(bounds) - buttonSize.width), commandButtonY);
	
	blessButton.size = playButton.size = knotButton.size = buttonSize;
	
	// See if we've clicked a button
	NSRect buttonRect;
	
	clickedItem = item;
	clickedButton = IFTranscriptNoButton;
	
	if (NSPointInRect(viewPos, blessButton)) {
		clickedButton = IFTranscriptButtonBless;
		buttonRect = blessButton;
	} else if (NSPointInRect(viewPos, playButton)) {
		clickedButton = IFTranscriptButtonPlayToHere;
		buttonRect = playButton;
	} else if (NSPointInRect(viewPos, knotButton)) {
		clickedButton = IFTranscriptButtonShowKnot;
		buttonRect = knotButton;
	}
	
	if (clickedButton != IFTranscriptNoButton) {
		// A button has been clicked: wait for the user to let go or move the mouse out of the buttons rectangle
		enum IFTranscriptButton trackedButton = clickedButton;
		
		[self setNeedsDisplayInRect: buttonRect];
		
		// While the mouse is held down, track the button
		while (1) {
			NSEvent* theEvent;
			theEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
			
			NSPoint point = [self convertPoint: [theEvent locationInWindow]
									  fromView: nil];
			if (clickedButton != trackedButton && NSPointInRect(point, buttonRect)) {
				// User has moved the mouse into the button area
				clickedButton = trackedButton;
				[self setNeedsDisplayInRect: buttonRect];
			} else if (clickedButton == trackedButton && !NSPointInRect(point, buttonRect)) {
				// User has moved the mouse outside the button area
				clickedButton = IFTranscriptNoButton;
				[self setNeedsDisplayInRect: buttonRect];
			}
			
			if ([theEvent type] == NSLeftMouseUp) {
				// User has finished holding down the mouse button
				break;
			}
		}
		
		// Notify the delegate
		switch (clickedButton) {
			case IFTranscriptButtonBless:
				[self transcriptBless: item];
				break;
				
			case IFTranscriptButtonPlayToHere:
				[self transcriptPlayToItem: [item skeinItem]];
				break;
				
			case IFTranscriptButtonShowKnot:
				[self transcriptShowKnot: [item skeinItem]];
				break;
				
			default:
				// Do nothing
				;
		}
		
		// Remove the button highlight
		clickedButton = IFTranscriptNoButton;
		[self setNeedsDisplayInRect: buttonRect];
		
		return;
	}
	
	// Clicking on the left or right-hand side activates the field editor
	if (item != nil && itemPos.y > fontHeight * 1.5) {
		[[self window] makeFirstResponder: self];
		
		NSTextView* fieldEditor = (NSTextView*)[[self window] fieldEditor: YES
																forObject: item];
		
		if (itemPos.x < bounds.size.width/2.0) {
			// Clicking in the left-hand field gives us a field editor for that field
			[item setupFieldEditor: fieldEditor
					   forExpected: NO
						   atPoint: NSMakePoint(NSMinX(bounds), NSMinY(bounds) + itemOffset)];
			
			[fieldEditor setEditable: NO];
		} else {
			// Clicking in the right-hand field gives us a field editor for that field
			[item setupFieldEditor: fieldEditor
					   forExpected: YES
						   atPoint: NSMakePoint(NSMinX(bounds), NSMinY(bounds) + itemOffset)];
			
			[fieldEditor setEditable: YES];
		}
		
		// Finish setting up the field editor (the item itself handles everything else)
		[self addSubview: fieldEditor];
		[fieldEditor setSelectedRange: NSMakeRange(0,0)];
		[[self window] makeFirstResponder: fieldEditor];
		[fieldEditor mouseDown: evt];
	}
	
	// Clicking on the command also activates the field editor
	if (item != nil && itemPos.y > fontHeight * 0.25 && itemPos.y < fontHeight*1.25) {
		[[self window] makeFirstResponder: self];
		
		NSTextView* fieldEditor = (NSTextView*)[[self window] fieldEditor: YES
																forObject: item];
		
		[item setupFieldEditorForCommand: fieldEditor
								  margin: [(NSImage*)[IFImageCache loadResourceImage: @"App/Transcript/Bless.png"] size].width*2.0
								 atPoint: NSMakePoint(NSMinX(bounds), NSMinY(bounds) + itemOffset)];
		
		[fieldEditor setEditable: [[item skeinItem] parent] != nil];

		// Finish setting up the field editor (the item itself handles everything else)
		[self addSubview: fieldEditor];
		[fieldEditor setSelectedRange: NSMakeRange(0,0)];
		[[self window] makeFirstResponder: fieldEditor];
		[fieldEditor mouseDown: evt];
	}
}

- (void)addCursorRect: (NSRect) aRect 
			   cursor: (NSCursor*) aCursor
			   inRect: (NSRect) maxRect {
	// Why this was too hard for Apple to do themselves eludes me
	if (!NSIntersectsRect(aRect, maxRect)) return;
	
	NSRect realRect = NSIntersectionRect(aRect, maxRect);
	
	[self addCursorRect: realRect
				 cursor: aCursor];
}

- (BOOL) acceptsFirstResponder {
	return YES;
}

- (void) resetCursorRects {
	// Get the visible items
	NSRect bounds = [self bounds];
	NSRect visibleArea = [self visibleRect];
	NSArray* cursorItems = [layout itemsInRect: visibleArea];
	
	float width = bounds.size.width;
	float fontHeight = -1;
	float buttonWidth = [(NSImage*)[IFImageCache loadResourceImage: @"App/Transcript/Bless.png"] size].width;
	
	NSCursor* iBeam = [NSCursor IBeamCursor];
	
	// I-Beam cursor for the command, and the left and right halfs of the items
	for( IFTranscriptItem* item in cursorItems ) {
		if (![item calculated]) continue;
		
		// (Lazy: only calculate fontHeight once)
		if (fontHeight < 0) {
            NSFont *font = [[item attributes] objectForKey: NSFontAttributeName];
			fontHeight = [layoutManager defaultLineHeightForFont:font];
		}
		
		float offset = [item offset];
		NSRect cursorRect;
		
		// Command I-Beam
		cursorRect.origin = NSMakePoint(NSMinX(bounds), NSMinY(bounds) + offset);
		cursorRect.size   = NSMakeSize(width - buttonWidth*2.0, fontHeight*1.5);
		
		[self addCursorRect: cursorRect
					 cursor: iBeam
					 inRect: visibleArea];
		
		// Left text view
		cursorRect.origin = NSMakePoint(NSMinX(bounds) + 8.0, NSMinY(bounds) + offset + fontHeight*1.75);
		cursorRect.size   = NSMakeSize(floorf(width/2.0 - 44.0), [item textHeight]);
		
		[self addCursorRect: cursorRect
					 cursor: iBeam
					 inRect: visibleArea];
		
		// Right text view
		cursorRect.origin = NSMakePoint(floorf(NSMinX(bounds) + width/2.0 + 36.0), cursorRect.origin.y);
		
		[self addCursorRect: cursorRect
					 cursor: iBeam
					 inRect: visibleArea];
	}
}

// = Displaying specific items =

- (void) scrollToItem: (ZoomSkeinItem*) item {
	NSRect bounds = [self bounds];
	NSRect visible = [self visibleRect];
	float offset = [layout offsetOfItem: item];
	
	if (offset >= 0) {
		NSRect itemRect;
		
		itemRect.origin = NSMakePoint(NSMinX(bounds), NSMinY(bounds) + offset);
		itemRect.size = NSMakeSize(bounds.size.width, [layout heightOfItem: item]);
		
		// Center the item in the display?
		float expandBy = floorf((visible.size.height - itemRect.size.height)/2.0);
		if (expandBy > 0) {
			itemRect.origin.y -= expandBy;
			itemRect.size.height += expandBy*2.0;
		}
		
		[self scrollRectToVisible: itemRect];
	}
}

- (void) setHighlightedItem: (ZoomSkeinItem*) item {
	IFTranscriptItem* transItem = nil;
	
	if (item) transItem = [layout itemForItem: item];
	
	if (transItem != highlightedItem) {
		highlightedItem = transItem;
		
		// FIXME: only draw the items as required
		[self setNeedsDisplay: YES];
	}
}

- (ZoomSkeinItem*) highlightedItem {
	// Retrieves the currently highlighted item
	return [highlightedItem skeinItem];
}

- (void) setActiveItem: (ZoomSkeinItem*) item {
	IFTranscriptItem* transItem = nil;
	
	if (item) transItem = [layout itemForItem: item];
	
	if (transItem != activeItem) {
		activeItem = transItem;
		
		// FIXME: only draw the items as required
		[self setNeedsDisplay: YES];
	}
}

// = The delegate =

- (void) setDelegate: (id) newDelegate {
	delegate = newDelegate;
}

- (void) transcriptPlayToItem: (ZoomSkeinItem*) knot {
	if (delegate && [delegate respondsToSelector: @selector(transcriptPlayToItem:)]) {
		[delegate transcriptPlayToItem: knot];
	}
}

- (void) transcriptShowKnot: (ZoomSkeinItem*) knot {
	if (delegate && [delegate respondsToSelector: @selector(transcriptShowKnot:)]) {
		[delegate transcriptShowKnot: knot];
	}
}

- (void) transcriptBless: (IFTranscriptItem*) itemToBless {
	if (delegate && [delegate respondsToSelector: @selector(transcriptBless:)]) {
		[delegate transcriptBless: itemToBless];
	} else {
		ZoomSkeinItem* skeinItem = [itemToBless skeinItem];
	
		[skeinItem setCommentary: [skeinItem result]];
	}
}

// = Some actions we can perform =

- (void) blessAll {
	[layout blessAll];
}

@end
