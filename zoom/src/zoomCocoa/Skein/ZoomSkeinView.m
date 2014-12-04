//
//  ZoomSkeinView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jul 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinView.h"
#import "ZoomSkeinLayout.h"

#include <Carbon/Carbon.h>

// Constants
static const float defaultItemWidth = 82.0;     // Pixels
static const float defaultItemHeight = 64.0;
static const float itemButtonBarWidth = 40.0;

// Drawing info
static NSDictionary* itemTextAttributes;

// Images
static NSImage* add, *delete, *locked, *unlocked, *annotate, *transcript;

// Buttons
enum ZSVbutton
{
	ZSVnoButton = 0,
	ZSVaddButton,
	ZSVdeleteButton,
	ZSVlockButton,
	ZSVannotateButton,
	ZSVtranscriptButton,

	ZSVmainItem = 256
};

NSString* ZoomSkeinItemPboardType = @"ZoomSkeinItemPboardType";

// Our sooper sekrit interface
@interface ZoomSkeinView(ZoomSkeinViewPrivate)

// Layout
- (void) layoutSkein;
- (void) updateTrackingRects;
- (void) removeAllTrackingRects;

// UI
- (void) mouseEnteredView;
- (void) mouseLeftView;
- (void) mouseEnteredItem: (ZoomSkeinItem*) item;
- (void) mouseLeftItem: (ZoomSkeinItem*) item;

- (enum ZSVbutton) buttonUnderPoint: (NSPoint) point
							 inItem: (ZoomSkeinItem*) item;

- (void) addButtonClicked: (NSEvent*) event
				 withItem: (ZoomSkeinItem*) item;
- (void) deleteButtonClicked: (NSEvent*) event
					withItem: (ZoomSkeinItem*) item;
- (void) annotateButtonClicked: (NSEvent*) event
					  withItem: (ZoomSkeinItem*) item;
- (void) transcriptButtonClicked: (NSEvent*) event
						withItem: (ZoomSkeinItem*) item;
- (void) lockButtonClicked: (NSEvent*) event
				  withItem: (ZoomSkeinItem*) item;
- (void) playToPoint: (ZoomSkeinItem*) item;

- (void) cancelEditing: (id) sender;
- (void) finishEditing: (id) sender;

- (void) editSoon: (ZoomSkeinItem*) item;
- (void) editItem: (ZoomSkeinItem*) skeinItem
	   annotation: (BOOL) annotation;
- (void) iHateEditing;

@end

@implementation ZoomSkeinView

+ (NSImage*) imageNamed: (NSString*) name {
	NSImage* img = [NSImage imageNamed: name];
	
	if (img == nil) {
		// Try to load from the framework instead
		NSBundle* ourBundle = [NSBundle bundleForClass: [self class]];
		NSString* filename = [ourBundle pathForResource: name
												 ofType: @"png"];
		
		if (filename) {
			img = [[[NSImage alloc] initWithContentsOfFile: filename] autorelease];
		}
	}
	
	[img setFlipped: YES];
	return img;
}

+ (void) initialize {
	add        = [[[self class] imageNamed: @"SkeinAdd"] retain];
	delete     = [[[self class] imageNamed: @"SkeinDelete"] retain];
	locked     = [[[self class] imageNamed: @"SkeinLocked"] retain];
	unlocked   = [[[self class] imageNamed: @"SkeinUnlocked"] retain];
	annotate   = [[[self class] imageNamed: @"SkeinAnnotate"] retain];
	transcript = [[[self class] imageNamed: @"SkeinTranscript"] retain];
	
	itemTextAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont systemFontOfSize: 10], NSFontAttributeName,
		[NSColor blackColor], NSForegroundColorAttributeName,
		nil] retain];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
	
    if (self) {
		skein = [[ZoomSkein alloc] init];
		activeButton = ZSVnoButton;
		
		layout = [[ZoomSkeinLayout alloc] init];
		[layout setRootItem: [skein rootItem]];
		
		itemWidth = defaultItemWidth;
		itemHeight = defaultItemHeight;
		
		[self registerForDraggedTypes: [NSArray arrayWithObjects: ZoomSkeinItemPboardType, nil]];
    }
	
    return self;
}

- (void) dealloc {
	[skein release];
	
	if (trackingRects)  [trackingRects release];

	if (itemToEdit)     [itemToEdit release];
	if (fieldScroller)  [fieldScroller release];
	if (fieldStorage)   [fieldStorage release];
	
	if (trackedItem)    [trackedItem release];
	if (clickedItem)    [clickedItem release];
	if (trackingItems)  [trackingItems release];
	if (mostRecentItem) [mostRecentItem release];

	[layout release];
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	[super dealloc];
}

// = Drawing =

+ (void) drawButton: (NSImage*) button
			atPoint: (NSPoint) pt
		highlighted: (BOOL) highlight {
	NSRect imgRect;
	
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [button size];
	
	if (!highlight) {
		[button drawAtPoint: pt
				   fromRect: imgRect
				  operation: NSCompositeSourceOver
				   fraction: 1.0];
	} else {
		NSImage* highlighted = [[NSImage alloc] initWithSize: imgRect.size];
		
		[highlighted lockFocus];
		
		// Background
		[[NSColor colorWithDeviceRed: 0.0
							   green: 0.0
								blue: 0.0
							   alpha: 0.4] set];
		NSRectFill(imgRect);
		
		// The item
		[button drawAtPoint: NSMakePoint(0,0)
				   fromRect: imgRect
				  operation: NSCompositeDestinationAtop
				   fraction: 1.0];
		
		[highlighted unlockFocus];
		
		// Draw
		[highlighted drawAtPoint: pt
						fromRect: imgRect
					   operation: NSCompositeSourceOver
						fraction: 1.0];
		
		// Release
		[highlighted release];
	}
}

- (void)drawRect:(NSRect)rect {
	if (skeinNeedsLayout) [self layoutSkein];
	
	// (Sigh, will fail to keep track of these properly otherwise)
	NSRect visRect = [self visibleRect];
	if (!NSEqualRects(visRect, lastVisibleRect)) {
		// Need to only update this occasionally, or some redraws may cause an infinite loop
		[self updateTrackingRects];
	}
	lastVisibleRect = visRect;
	
	[layout setActiveItem: [skein activeItem]];
	[layout drawInRect: rect];
	
	// Draw the control icons for the tracked item
	if (trackedItem != nil) {
		float xpos = [layout xposForItem: trackedItem];
		float ypos = ((float)[layout levelForItem: trackedItem])*itemHeight + (itemHeight / 2.0);
		float bgWidth =	[[trackedItem command] sizeWithAttributes: itemTextAttributes].width;
		
		// Layout is:
		//    A T        x +
		//    ( ** ITEM ** )
		//                 L
		// 
		// Where A = Annotate, T = transcript, x = delete, + = add, L = lock
		float w = bgWidth;
		if (w < itemButtonBarWidth) w = itemButtonBarWidth;
		w += 40.0;
		float left = xpos - w/2.0;
		float right = xpos + w/2.0;
		
		ZoomSkeinItem* itemParent = [trackedItem parent];
		
		// Correct for shadow
		right -= 20.0;
		left  += 2.0;
		
		// Draw the buttons
		NSRect imgRect;
		imgRect.origin = NSMakePoint(0,0);
		imgRect.size   = [add size];
		
		if (itemParent != nil) {
			// Can't annotate the parent item (well, technically we can, but the editor routine we have at the moment will break if we try to edit the top item)
			[[self class] drawButton: annotate
							 atPoint: NSMakePoint(left, ypos - 18)
						 highlighted: activeButton == ZSVannotateButton];
		}
		[[self class] drawButton: transcript
						 atPoint: NSMakePoint(left + 14, ypos - 18)
					 highlighted: activeButton==ZSVtranscriptButton];
		
		[[self class] drawButton: add
						 atPoint: NSMakePoint(right, ypos - 18)
					 highlighted: activeButton==ZSVaddButton];
		if (itemParent != nil) {
			// Can only delete items other than the parent 'start' item
			[[self class] drawButton: delete
							 atPoint: NSMakePoint(right - 14, ypos - 18)
						 highlighted: activeButton==ZSVdeleteButton];
		}
		
		if (itemParent != nil) {
			// Can't unlock the 'start' item
			NSImage* lock = [trackedItem temporary]?unlocked:locked;
			
			[[self class] drawButton: lock
							 atPoint: NSMakePoint(xpos - 8, ypos - 18)
						 highlighted: activeButton==ZSVlockButton];
		}
	}
}

- (BOOL) isFlipped {
	return YES;
}

// = Setting/getting the source =

- (ZoomSkein*) skein {
	return skein;
}

- (void) setSkein: (ZoomSkein*) sk {
	if (skein == sk) return;
	
	if (skein) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: ZoomSkeinChangedNotification
													  object: skein];
		[skein release];
	}
	
	skein = [sk retain];
	[layout setRootItem: [sk rootItem]];
	
	if (skein) {
		// Fixed by Collin Pieper: adding an observer for nil has somewhat unwanted side effects
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(skeinDidChange:)
													 name: ZoomSkeinChangedNotification
												   object: skein];
	}
	
	[self setSelectedItem: nil];
	[self skeinNeedsLayout];
	
	[self layoutSkein];
	[self updateTrackingRects];
	[self scrollToItem: [skein activeItem]];
}

// = Laying things out =

- (void) skeinDidChange: (NSNotification*) not {
	[self finishEditing: self];
	[self skeinNeedsLayout];
	
	[self scrollToItem: mostRecentItem];
	[mostRecentItem release]; mostRecentItem = nil;
}

- (void) skeinNeedsLayout {
	if (!skeinNeedsLayout) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(layoutSkein)
											 target: self
										   argument: nil
											  order: 8
											  modes: [NSArray arrayWithObjects: NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
		skeinNeedsLayout = YES;
	}
}

- (void) setItemWidth: (float) newItemWidth {
	if (newItemWidth < 16.0) newItemWidth = 16.0;
	if (newItemWidth == itemWidth) return;
	itemWidth = newItemWidth;
	
	[self skeinNeedsLayout];
}

- (void) setItemHeight: (float) newItemHeight {
	if (newItemHeight < 16.0) newItemHeight = 16.0;
	if (newItemHeight == itemHeight) return;
	itemHeight = newItemHeight;
	
	[self skeinNeedsLayout];
	[self setNeedsDisplay: YES];
}

- (void) layoutSkein {
	// Only actually layout if we're marked as needing it
	if (!skeinNeedsLayout) return;
	
	skeinNeedsLayout = NO;
	
	// Re-layout this skein
	[layout setItemWidth: itemWidth];
	[layout setItemHeight: itemHeight];
	[layout setRootItem: [skein rootItem]];
	[layout layoutSkein];
	
	// Resize this view
	NSRect newBounds = [self frame];
	
	newBounds.size = [layout size];
	
	[self setFrameSize: newBounds.size];
	
	// View needs redisplaying
	[self setNeedsDisplay: YES];
	
	// ... and redo the tracking rectangles
	[self updateTrackingRects];
}

// = Affecting the display =

- (void) scrollToItem: (ZoomSkeinItem*) item {
	if (item == nil) item = [skein activeItem];
	if ([self superview] == nil) return;
	
	[mostRecentItem release];
	mostRecentItem = [item retain];
	
	if (skeinNeedsLayout) [self layoutSkein];
	
	ZoomSkeinLayoutItem* foundItem = [layout dataForItem: item];
	
	if (foundItem) {
		float xpos, ypos;
		
		xpos = [layout xposForItem: item];
		ypos = [layout levelForItem: item]*itemHeight + (itemHeight / 2);
		
		NSRect visRect = [self visibleRect];
		
		xpos -= visRect.size.width / 2.0;
		ypos -= visRect.size.height / 3.0;
		
		[self scrollPoint: NSMakePoint(floorf(xpos), floorf(ypos))];
	} else {
		NSLog(@"ZoomSkeinView: Attempt to scroll to nonexistent item");
	}
}

// = Skein mouse sensitivity =

- (void) removeAllTrackingRects {
	NSEnumerator* trackingEnum = [trackingRects objectEnumerator];
	NSNumber* val;
	
	while (val = [trackingEnum nextObject]) {
		[self removeTrackingRect: [val intValue]];
	}
	
	[trackingRects release];
	trackingRects = [[NSMutableArray alloc] init];
	
	[trackingItems release];
	trackingItems = [[NSMutableArray alloc] init];
}

- (void) updateTrackingRects {
	if (dragScrolling) return;
	if ([self superview] == nil || [self window] == nil) return;

	[self removeAllTrackingRects];
	
	NSPoint currentMousePos = [[self window] mouseLocationOutsideOfEventStream];
	currentMousePos = [self convertPoint: currentMousePos
								fromView: nil];
	
	// Only put in the visible items
	NSRect visibleRect = [self visibleRect];
	
	if (overItem)   [self mouseLeftItem: trackedItem];
	if (overWindow) [self mouseLeftView];
	overWindow = NO;
	overItem = NO;
	if (trackedItem) [trackedItem release];
	trackedItem = nil;

	int startLevel = floorf(NSMinY(visibleRect) / itemHeight)-1;
	int endLevel = ceilf(NSMaxY(visibleRect) / itemHeight);
	
	NSTrackingRectTag tag;
	BOOL inside = NO;

	int level;
	
	if (startLevel < 0) startLevel = 0;
	if (endLevel >= [layout levels]) endLevel = [layout levels]-1;
	
	// assumeInside: NO doesn't work if the pointer is already inside (acts exactly the same as assumeInside: YES 
	// in this case). Therefore we need to check manually, which is very annoying.
	inside = NO;
	if (NSPointInRect(currentMousePos, visibleRect)) {
		[self mouseEnteredView];
		inside = YES;
	}
	tag = [self addTrackingRect: visibleRect
						  owner: self
					   userData: nil
				   assumeInside: inside];
		
	[trackingRects addObject: [NSNumber numberWithInt: tag]];
	
	for (level = startLevel; level<=endLevel; level++) {
		NSEnumerator* itemEnum = [[layout itemsOnLevel: level] objectEnumerator];
		ZoomSkeinItem* item;
		
		while (item = [itemEnum nextObject]) {
			NSRect itemRect = [layout activeAreaForItem: item];
			
			if (!NSIntersectsRect(itemRect, visibleRect)) continue;
			itemRect = NSIntersectionRect(itemRect, visibleRect);
			
			// Same reasoning as before
			[trackingItems addObject: item];
			inside = NO;
			if (NSPointInRect(currentMousePos, itemRect)) {
				[self mouseEnteredItem: item];
				inside = YES;
			}
			tag = [self addTrackingRect: itemRect
								  owner: self
							   userData: item
						   assumeInside: inside];
			[trackingRects addObject: [NSNumber numberWithInt: tag]];
		}
	}
}

- (void) mouseEnteredView {
	if (!overItem && !overWindow) {
		[[NSCursor openHandCursor] push];
	}
	
	overWindow = YES;
}

- (void) mouseLeftView {
	if (overItem) { [NSCursor pop]; overItem = NO; }
	if (overWindow) [NSCursor pop];
	overWindow = NO;
	trackedItem = nil;
}

- (void) mouseEnteredItem: (ZoomSkeinItem*) item {
	if (skeinNeedsLayout) {
		[self layoutSkein];
		[self updateTrackingRects];
		return;
	}
	
	if ([trackingItems indexOfObjectIdenticalTo: item] == NSNotFound) {
		NSLog(@"Item %p does not exist in SkeinView! (tracking error)", item);
		return;
	}
	
	if (!overWindow) {
		// Make sure the cursor stack is set up correctly
		[[NSCursor openHandCursor] push];
		overWindow = YES;
	}
	
	if (!overItem) {
		[[NSCursor pointingHandCursor] push];
	}
	
	if (trackedItem) {
		[trackedItem release];
	}
	trackedItem = [item retain];
	overItem = YES;
	
	if (trackedItem) {
		[self setNeedsDisplay: YES];
	}
}

- (void) mouseLeftItem: (ZoomSkeinItem*) item {
	if (overItem) [NSCursor pop];
	if (trackedItem) [self setNeedsDisplay: YES];
	overItem = NO;
	if (trackedItem) [trackedItem release];
	trackedItem = nil;
	
	[self iHateEditing];
}

- (void) mouseEntered: (NSEvent*) event {
	// Entered a tracking rectangle: switch to the arrow tracking cursor
	if ([event userData] == nil) {
		// Entered the main view tracking rectangle
		[self mouseEnteredView];
	} else {
		// Entered a tracking rectangle for a specific item
		[self mouseEnteredItem: [event userData]];
	}
}

- (void) mouseExited: (NSEvent*) event {
	// Exited a tracking rectangle: switch to the open hand cursor
	if ([event userData] == nil) {
		// Leaving the view entirely
		[self mouseLeftView];
	} else {
		// Left a item tracking rectangle
		[self mouseLeftItem: [event userData]];
	}
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
	return YES;
}

- (BOOL) acceptsFirstResponder {
	return YES;
}

// = Mouse handling =

- (void) mouseDown: (NSEvent*) event {
	[self finishEditing: self];
	
	// Update the tracked item if it's not accurate
	NSPoint pointInView = [event locationInWindow];
	pointInView = [self convertPoint: pointInView fromView: nil];
	
	ZoomSkeinItem* realItem = [layout itemAtPoint: pointInView];
	
	if (realItem != trackedItem) {
		if (!overWindow) [self mouseEnteredView];
		
		if (trackedItem) [self mouseLeftItem: trackedItem];
		if (realItem) [self mouseEnteredItem: realItem];
	}
	
	if (clickedItem) [clickedItem release];
	clickedItem = [realItem retain];
	
	if (trackedItem == nil) {
		// We're dragging to move the view around
		[[NSCursor closedHandCursor] push];
		
		dragScrolling = YES;
		dragOrigin = [event locationInWindow];
		dragInitialVisible = [self visibleRect];
	} else {
		// We're inside an item - check to see which (if any) button was clicked
		activeButton = lastButton = [self buttonUnderPoint: [self convertPoint: [event locationInWindow] 
																	  fromView: nil]
													inItem: trackedItem];
		[self setNeedsDisplay: YES];
	}
}

- (void) mouseDragged: (NSEvent*) event {
	if (dragScrolling) {
		// Scroll to the new position
		NSPoint currentPos = [event locationInWindow];
		NSRect newVisRect = dragInitialVisible;
		
		newVisRect.origin.x += dragOrigin.x - currentPos.x;
		newVisRect.origin.y -= dragOrigin.y - currentPos.y;
		
		[self scrollRectToVisible: NSIntegralRect(newVisRect)];
	} else if (clickedItem != nil && (lastButton == ZSVmainItem)) {
		// Drag this item. Default action is a copy action, but a move op is possible if command is held
		// down.
		lastButton = ZSVnoButton;
		
		// Create an image of this item
		NSImage* itemImage = [layout imageForItem: clickedItem];
		
		NSPasteboard *pboard;
		
		dragCanMove = ![clickedItem hasChild: [skein activeItem]];
		
		pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		[pboard declareTypes:[NSArray arrayWithObjects: ZoomSkeinItemPboardType, nil] owner:self];

		[pboard setData: [NSKeyedArchiver archivedDataWithRootObject: clickedItem]
				forType: ZoomSkeinItemPboardType];
		
		NSPoint origin;
		
		origin.x = [layout xposForItem: clickedItem] - [layout widthForItem: clickedItem]/2.0 - 20.0;
		origin.y = ((float)[layout levelForItem: clickedItem])*itemHeight + (itemHeight/2.0);
		origin.y += 22.0;
		
		[self dragImage: itemImage
					 at: origin
				 offset: NSMakeSize(0,0)
				  event: event
			 pasteboard: pboard
				 source: self
			  slideBack: YES];
	} else if (trackedItem != nil && lastButton != ZSVnoButton) {
		// If the cursor moves away from a button, then unhighlight it
		int lastActiveButton = activeButton;
		
		activeButton = [self buttonUnderPoint: [self convertPoint: [event locationInWindow] 
														 fromView: nil]
									   inItem: trackedItem];
		if (activeButton != lastButton) activeButton = ZSVnoButton;
		
		if (activeButton != lastActiveButton) [self setNeedsDisplay: YES];
	}	
}

- (void) mouseUp: (NSEvent*) event {
	[self iHateEditing];
	
	if (clickedItem) {
		[clickedItem release];
		clickedItem = nil;
	}
	
	if (dragScrolling) {
		dragScrolling = NO;
		[NSCursor pop];
		
		[[NSRunLoop currentRunLoop] performSelector: @selector(updateTrackingRects)
											 target: self
										   argument: nil
											  order: 64
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
	} else if (trackedItem != nil) {
		// Finish a click on any item button
		if (activeButton != ZSVnoButton) {
			switch (activeButton) {
				case ZSVaddButton:
					[self addButtonClicked: event
								  withItem: trackedItem];
					break;
					
				case ZSVdeleteButton:
					[self deleteButtonClicked: event
									 withItem: trackedItem];
					break;

				case ZSVannotateButton:
					[self annotateButtonClicked: event
									   withItem: trackedItem];
					break;
					
				case ZSVtranscriptButton:
					[self transcriptButtonClicked: event
										 withItem: trackedItem];
					break;

				case ZSVlockButton:
					[self lockButtonClicked: event
								   withItem: trackedItem];
					break;
					
				case ZSVmainItem:
					if ([event modifierFlags]&NSAlternateKeyMask && [event clickCount] == 1) {
						// Clicking with the option key edits immediately
						[self editItem: trackedItem];
					} else if ([event modifierFlags]&NSCommandKeyMask || [event clickCount] == 2) {
						// Run the game to this point (double- or command- click)
						[self playToPoint: trackedItem];
					} else if ([event clickCount] == 1) {
						// Select this item - queue up for editing if required
						if ([layout selectedItem] != trackedItem) {
							// Change the selected item
							[self setSelectedItem: trackedItem];
							
							// Edit soon
							[self editSoon: trackedItem];
						} else {
							// Edit soon
							[self editSoon: trackedItem];
						}
					}
					//[self editItem: [trackedItem objectForKey: ZSitem]];
					break;
			}
			
			activeButton = ZSVnoButton;
			[self setNeedsDisplay: YES];
		}
	}

	// Reset this anyway
	activeButton = ZSVnoButton;	
	lastButton = ZSVnoButton;
}

- (enum ZSVbutton) buttonUnderPoint: (NSPoint) point
							 inItem: (ZoomSkeinItem*) item {
	// Calculate info about the location of this item
	float xpos = [layout xposForItem: item];
	float ypos = ((float)[layout levelForItem: item]) * itemHeight + (itemHeight/2.0);

	NSDictionary* fontAttrs = itemTextAttributes;
	
	NSSize size = [[item command] sizeWithAttributes: fontAttrs];

	float w = size.width; //[[item objectForKey: ZSwidth] floatValue];
	if (w < itemButtonBarWidth) w = itemButtonBarWidth;
	w += 40.0;
	float left = -w/2.0;
	float right = w/2.0;
	float lozengeRight = size.width/2.0;
	
	// Correct for shadow
	right -= 20.0;
	left  += 2.0;				

	// Actual position
	NSPoint offset = NSMakePoint(point.x - xpos, point.y - ypos);
	
	// See where was clicked
	if (offset.y > -18.0 && offset.y < -6.0) {
		// Upper row of buttons
		if (offset.x > left+2.0 && offset.x < left+14.0) return [item parent]!=nil?ZSVannotateButton:ZSVnoButton;
		if (offset.x > left+16.0 && offset.x < left+28.0) return ZSVtranscriptButton;
		if (offset.x > right+2.0 && offset.x < right+14.0) return ZSVaddButton;
		if (offset.x > right-12.0 && offset.x < right-0.0) return ZSVdeleteButton;
		if (offset.x > -8 && offset.x < 8) return ZSVlockButton;
	} else if (offset.y > 18.0 && offset.y < 30.0) {
		// Lower row of buttons
	} else if ([item commentaryComparison] == ZoomSkeinDifferent
			   && offset.x > lozengeRight + 4.0 && offset.x < lozengeRight + 20.0
			   && offset.y > 6.0 && offset.y < 22.0) {
		// Comparison failed badge
		return ZSVtranscriptButton;
	} else if (offset.y > -2.0 && offset.y < 14.0) {
		// Main item
		return ZSVmainItem;
	} else {
		// Nothing
	}
	
	return ZSVnoButton;
}

// = Item control buttons =

- (void) addButtonClicked: (NSEvent*) event
				 withItem: (ZoomSkeinItem*) skeinItem {
	// Add a new, blank item
	ZoomSkeinItem* newItem = 
		[skeinItem addChild: [ZoomSkeinItem skeinItemWithCommand: @""]];
	
	// Lock it
	[newItem setTemporary: NO];
	
	// Note the changes
	[skein zoomSkeinChanged];	
	[self skeinNeedsLayout];
	
	// Edit the item
	[self scrollToItem: newItem];
	[self editItem: newItem];
}

- (void) deleteButtonClicked: (NSEvent*) event
					withItem: (ZoomSkeinItem*) skeinItem {
	ZoomSkeinItem* itemParent = [skeinItem parent];
	
	if ([skeinItem parent] == nil) return;
	
	ZoomSkeinItem* parent = [skein activeItem];
	while (parent != nil) {
		if (parent == skeinItem) {
			if (![delegate respondsToSelector: @selector(cantDeleteActiveBranch)]) {
				// Can't delete an item that's the parent of the active item
				NSBeep();
			} else {
				[delegate cantDeleteActiveBranch];
			}
			return;
		}
		
		parent = [parent parent];
	}
	
	// Delete the item
	[skeinItem removeFromParent];
	[skein zoomSkeinChanged];
	[self skeinNeedsLayout];
	
	if (itemParent) {
		[self scrollToItem: itemParent];
	}
}

- (void) lockButtonClicked: (NSEvent*) event
				  withItem: (ZoomSkeinItem*) skeinItem {
	if ([skeinItem parent] == nil) return;

	if ([skeinItem temporary]) {
		[skeinItem setTemporary: NO];
	} else {
		// Unlock this item and its children
		
		// itemsToProcess is a stack of items
		NSMutableArray* itemsToProcess = [NSMutableArray array];
		[itemsToProcess addObject: skeinItem];
		
		while ([itemsToProcess count] > 0) {
			ZoomSkeinItem* thisItem = [itemsToProcess lastObject];
			[itemsToProcess removeLastObject];
	
			[thisItem setTemporary: YES];
	
			NSEnumerator* childEnum = [[thisItem children] objectEnumerator];
			ZoomSkeinItem* child;
			while (child = [childEnum nextObject]) {
				[itemsToProcess addObject: child];
			}
		}
	}
	
	[self setNeedsDisplay: YES];
}

- (void) annotateButtonClicked: (NSEvent*) event
					  withItem: (ZoomSkeinItem*) skeinItem {
	// Provide an editor for the annotation rather than the item
	[self editItemAnnotation: skeinItem];
}

- (void) transcriptButtonClicked: (NSEvent*) event
						withItem: (ZoomSkeinItem*) skeinItem {
	if (![delegate respondsToSelector: @selector(transcriptToPoint:)]) {
		// Can't transcript to this point: delegate does not support it
		return;
	}
	
	[delegate transcriptToPoint: skeinItem];
}

// = Editing items =

- (void)textDidEndEditing:(NSNotification *)aNotification {
	// Check if the user left the field before committing changes and end the edit.
	BOOL success = [[[aNotification userInfo] objectForKey:@"NSTextMovement"] intValue] != NSIllegalTextMovement;
	
	if (success)
		[self finishEditing: fieldEditor];				// Store the results
	else
		[self cancelEditing: fieldEditor];				// Abort the edit
}

- (void) finishEditing: (id) sender {
	if (itemToEdit != nil && fieldEditor != nil) {
		ZoomSkeinItem* parent = [itemToEdit parent];
		
		BOOL samename;		// Set to YES if we need to remove and re-add
		
		if (!editingAnnotation && [parent childWithCommand: [fieldEditor string]] != itemToEdit) 
			samename = YES;
		else
			samename = NO;
		
		// This will merge trees if the item gets the same name as a neighbouring item
		if (samename) [itemToEdit removeFromParent];
		if (!editingAnnotation)
			[itemToEdit setCommand: [fieldEditor string]];
		else
			[itemToEdit setAnnotation: [fieldEditor string]];
		ZoomSkeinItem* newItem;
		
		if (samename)
			newItem = [parent addChild: itemToEdit];
		else
			newItem = itemToEdit;
		
		// Change the active item if required
		if (itemToEdit == [skein activeItem]) {
			[skein setActiveItem: newItem];
		}
		
		// NOTE: if 'addChild' can ever release the active item, we may have a problem here.
		// Currently, this can't happen

		[self skeinNeedsLayout];

		if (sender == fieldEditor) [self scrollToItem: itemToEdit];

		[self cancelEditing: self];
		[skein zoomSkeinChanged];
	} else {
		[self cancelEditing: self];
	}
}

- (void) cancelEditing: (id) sender {
	[self setNeedsDisplay: YES];
	[fieldScroller removeFromSuperview];
	
	if (fieldEditor == nil) return;
	
	// Kill off the field editor
	[fieldEditor removeFromSuperview];
	[[self window] makeFirstResponder: self];
	
	fieldEditor = nil;
	
	[itemToEdit release]; itemToEdit = nil;
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
	[self finishEditing: self];
}

- (void) editItemAnnotation: (ZoomSkeinItem*) skeinItem {
	[self editItem: skeinItem
		annotation: YES];
}

- (void) editItem: (ZoomSkeinItem*) skeinItem {
	[self editItem: skeinItem
		annotation: NO];
}

- (void) editItem: (ZoomSkeinItem*) skeinItem
	   annotation: (BOOL) annotation {
	// Finish any existing editing
	[self finishEditing: self];
	[[self window] makeFirstResponder: self];
	
	if ([skeinItem parent] == nil) {
		// Can't edit the root item
		if (![delegate respondsToSelector: @selector(cantEditRootItem)]) {
			NSBeep();
		} else {
			[delegate cantEditRootItem];
		}

		return;
	}
	
	// Allows you to edit an item's command or label ('annotation')
	ZoomSkeinLayoutItem* itemD = [layout dataForItem: skeinItem];
	
	if (itemD == nil) {
		NSLog(@"ZoomSkeinView: Item not found for editing");
		return;
	}
	
	// Get the text to edit
	NSString* itemText = annotation?[skeinItem annotation]:[skeinItem command];
	if (itemText == nil) itemText = @"";
	
	// Area of the text for this item
	NSRect itemFrame = [layout textAreaForItem: skeinItem];
    itemFrame = NSInsetRect(itemFrame, -10, 0);
	
	// (Or the annotation)
	if (annotation) itemFrame.origin.y -= 18;
	
	// Make sure the item is the right size
	float minItemWidth = itemWidth;
	if (itemFrame.size.width < minItemWidth) {
		itemFrame.origin.x  -= (minItemWidth - itemFrame.size.width)/2.0;
		itemFrame.size.width = minItemWidth;
	}
	
	// 'overflow' border
	itemFrame = NSInsetRect(itemFrame, -2.0, -2.0);	
	
	itemFrame.origin.x = floorf(itemFrame.origin.x);
	itemFrame.origin.y = floorf(itemFrame.origin.y)-1.0;
	itemFrame.size.width = floorf(itemFrame.size.width);
	itemFrame.size.height = floorf(itemFrame.size.height);
	
	itemToEdit = [skeinItem retain];
	
	editingAnnotation = annotation;
	
	// Construct the scroll view
	if (fieldScroller == nil) {
		fieldScroller = [[NSScrollView alloc] init];
		
		[fieldScroller setHasHorizontalScroller: NO];
		[fieldScroller setHasVerticalScroller: NO];
		[fieldScroller setBorderType: NSBezelBorder];
	}
	
	// Construct the field editor
	fieldEditor = (NSTextView*)[[self window] fieldEditor: YES
												forObject: self];
	
	if (fieldStorage) [fieldStorage release];
	fieldStorage = [[NSTextStorage alloc] initWithString: itemText
											  attributes: itemTextAttributes];	
	[[fieldEditor textStorage] setAttributedString: fieldStorage];
	[fieldEditor setSelectedRange: NSMakeRange(0,0)];
	
	[fieldEditor setDelegate: self];
	[fieldScroller setFrame: itemFrame];
	[fieldEditor setFrame: NSInsetRect(itemFrame, 2.0, 2.0)];
	
	[fieldEditor setAlignment: NSCenterTextAlignment];
	[fieldEditor setFont: [itemTextAttributes objectForKey: NSFontAttributeName]];
	
	[fieldEditor setRichText:NO];
	if ([fieldEditor respondsToSelector: @selector(setAllowsDocumentBackgroundColorChange:)]) [fieldEditor setAllowsDocumentBackgroundColorChange:NO];
	[fieldEditor setBackgroundColor:[NSColor whiteColor]];
	
	[[fieldEditor textContainer] setContainerSize: NSMakeSize(NSInsetRect(itemFrame, 2.0, 2.0).size.width, 1e6)];
	[[fieldEditor textContainer] setWidthTracksTextView:NO];
	[[fieldEditor textContainer] setHeightTracksTextView:NO];
	[fieldEditor setHorizontallyResizable:NO];
	[fieldEditor setVerticallyResizable:YES];
	[fieldEditor setDrawsBackground: YES];
	[fieldEditor setEditable: YES];
	
	// Activate it
	[fieldScroller setDocumentView: fieldEditor];
	[self addSubview: fieldScroller];
	[[self window] makeFirstResponder: fieldEditor];
	// [[self window] makeKeyWindow];
}


- (void) editSoon: (ZoomSkeinItem*) item {
	[self performSelector: @selector(editItem:)
			   withObject: item
			   afterDelay: 0.7];
}

- (void) iHateEditing {
	[NSObject cancelPreviousPerformRequestsWithTarget: self];
}

// = Selecting items =

- (void) setSelectedItem: (ZoomSkeinItem*) item {
	if (item == [layout selectedItem]) return;
	
	[layout setSelectedItem: item];
	
	[self setNeedsDisplay: YES];
}

- (ZoomSkeinItem*) selectedItem {
	return [layout selectedItem];
}

- (void) highlightSkeinLine: (ZoomSkeinItem*) itemOnLine {
	[layout highlightSkeinLine: itemOnLine];
	[self setNeedsDisplay: YES];
}

// = Playing the game =

- (void) playToPoint: (ZoomSkeinItem*) item {
	if (![delegate respondsToSelector: @selector(restartGame)] ||
		![delegate respondsToSelector: @selector(playToPoint:fromPoint:)]) {
		// Can't play to this point: delegate does not support it
		return;
	}
	
	// Make sure it won't disappear...
	[item increaseTemporaryScore];
	
	// Deselect the curently selected item
	[self setSelectedItem: nil];
	
	// Work out if we can play from the active item or not
	ZoomSkeinItem* activeItem = [skein activeItem];
	ZoomSkeinItem* parent = [item parent];
	
	while (parent != nil) {
		if (parent == activeItem) break;
		parent = [parent parent];
	}
	
	if (parent == nil) {
		// We need to play from the start
		[delegate restartGame];
		[delegate playToPoint: item
					fromPoint: [skein rootItem]];
	} else {
		// Play from the active item
		[delegate playToPoint: item
					fromPoint: activeItem];
	}
}

// = Delegate =

- (void) setDelegate: (id) dg {
	delegate = dg;
}

- (id) delegate {
	return delegate;
}

// = Moving around =

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
	[self finishEditing: self];
	[self removeAllTrackingRects];
}

- (void) viewWillMoveToSuperview:(NSView *)newSuperview {
	[self finishEditing: self];
	[self removeAllTrackingRects];
}

- (void)viewDidMoveToWindow {
	if ([self superview] != nil) [self skeinNeedsLayout];
}

- (void) viewDidMoveToSuperview {
	if ([self superview] != nil) [self skeinNeedsLayout];
}

- (void) setFrame: (NSRect) frame {
	[self skeinNeedsLayout];
	[super setFrame: frame];
}

- (void) setBounds: (NSRect) bounds {
	[self skeinNeedsLayout];
	[super setBounds: bounds];
}

// = NSDraggingSource protocol =

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
	if (isLocal) {
		if (dragCanMove) {
			return NSDragOperationCopy|NSDragOperationMove;
		} else {
			return NSDragOperationCopy;
		}
	} else {
		return NSDragOperationCopy;
	}
}

- (void)draggedImage:(NSImage *)anImage 
			 endedAt:(NSPoint)aPoint 
		   operation:(NSDragOperation)operation {
	if ((operation&NSDragOperationMove) && clickedItem != nil && dragCanMove) {
		[clickedItem removeFromParent];
		[self skeinNeedsLayout];
	}
}

// = NSDraggingDestination protocol =

- (NSDragOperation) updateDragCursor: (id <NSDraggingInfo>) sender {
	NSPoint dragPoint = [self convertPoint: [sender draggingLocation]
								  fromView: nil];
	ZoomSkeinItem* item = [layout itemAtPoint: dragPoint];
	
	if (item == nil || item == clickedItem || [item hasChildWithCommand: [clickedItem command]]) {
		SetThemeCursor(kThemeNotAllowedCursor);
		
		return NSDragOperationNone;
	} else {
		if ([sender draggingSourceOperationMask]&NSDragOperationMove &&
			![clickedItem hasChild: item]) {
			SetThemeCursor(kThemeArrowCursor);
			
			return NSDragOperationMove;
		} else {
			SetThemeCursor(kThemeCopyArrowCursor);
			
			return NSDragOperationCopy;
		}
	}
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	[[NSCursor arrowCursor] set];
	
	return [self updateDragCursor: sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
	return [self updateDragCursor: sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
	[[NSCursor arrowCursor] set];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
	// Refuse to accept the drag operation if the item is nil
	NSPoint dragPoint = [self convertPoint: [sender draggingLocation]
								  fromView: nil];
	ZoomSkeinItem* item = [layout itemAtPoint: dragPoint];

	return (item != nil);
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	NSPoint dragPoint = [self convertPoint: [sender draggingLocation]
								  fromView: nil];
	ZoomSkeinItem* item = [layout itemAtPoint: dragPoint];
	
	if (item == nil) return NO;
	
	// Decode the ZoomSkeinItemPboardType data for this operation
	NSPasteboard* pboard = [sender draggingPasteboard];
	NSData*       data = [pboard dataForType: ZoomSkeinItemPboardType];
	if (data == nil) return NO;
	
	ZoomSkeinItem* newItem = [NSKeyedUnarchiver unarchiveObjectWithData: data];
	if (newItem == nil) return NO;
	
	// Add this as a child of the old item
	[item addChild: newItem];
	
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
	[self skeinNeedsLayout];
	[self layoutSkein];

	NSPoint dragPoint = [self convertPoint: [sender draggingLocation]
								  fromView: nil];
	ZoomSkeinItem* item = [layout itemAtPoint: dragPoint];
	
	if (item == nil) return;
	
	[self scrollToItem: item];
}

// = Context menu =

- (NSMenu *)menuForEvent:(NSEvent *)event {
	// Find which item that the mouse is over
	NSPoint pointInView = [event locationInWindow];
	pointInView = [self convertPoint: pointInView fromView: nil];
	
	contextItem = [layout itemAtPoint: pointInView];
	
	if (contextItem == nil) return nil;
	
	NSMenu* contextMenu = [[NSMenu alloc] init];
	
	// Add menu items for the standard actions
	
	[contextMenu addItemWithTitle: @"Play to Here"
						   action: @selector(playToHere:)
					keyEquivalent: @""];
	
	[contextMenu addItem: [NSMenuItem separatorItem]];

	BOOL needSep = NO;
	if ([contextItem parent] != nil) {
		BOOL hasLabel = [[contextItem annotation] length] > 0;
		needSep = YES;
		[contextMenu addItemWithTitle: hasLabel?@"Edit Label":@"Add Label"
							   action: @selector(addAnnotation:)
						keyEquivalent: @""];
	}
	if ([delegate respondsToSelector: @selector(transcriptToPoint:)]) {
		needSep = YES;
		[contextMenu addItemWithTitle: @"Show in Transcript"
							   action: @selector(showInTranscript:)
						keyEquivalent: @""];
	}
	if ([contextItem parent] != nil) {
		needSep = YES;
		[contextMenu addItemWithTitle: [contextItem temporary]?@"Lock":@"Unlock"
							   action: @selector(toggleLock:)
						keyEquivalent: @""];
		[contextMenu addItemWithTitle: [contextItem temporary]?@"Lock this Thread":@"Unlock this Branch"
							   action: @selector(toggleLockBranch:)
						keyEquivalent: @""];
	}

	if (needSep) [contextMenu addItem: [NSMenuItem separatorItem]];

	if ([[contextItem children] count] > 0) {
		[contextMenu addItemWithTitle: @"New Thread"
							   action: @selector(addNewBranch:)
						keyEquivalent: @""];
	} else {
		[contextMenu addItemWithTitle: @"Add New"
							   action: @selector(addNewBranch:)
						keyEquivalent: @""];
	}

	if ([contextItem parent] != nil) {
		[contextMenu addItemWithTitle: @"Insert Knot"
							   action: @selector(insertItem:)
						keyEquivalent: @""];
		if ([[contextItem children] count] > 0) {
			[contextMenu addItemWithTitle: @"Delete"
								   action: @selector(deleteOneItem:)
							keyEquivalent: @""];
			[contextMenu addItemWithTitle: @"Delete all Below"
								   action: @selector(deleteItem:)
							keyEquivalent: @""];
		} else {
			[contextMenu addItemWithTitle: @"Delete"
								   action: @selector(deleteItem:)
							keyEquivalent: @""];
		}
		[contextMenu addItemWithTitle: @"Delete all in Thread"
							   action: @selector(deleteBranch:)
						keyEquivalent: @""];
	}
	
	[contextMenu addItem: [NSMenuItem separatorItem]];
	[contextMenu addItemWithTitle: @"Save Transcript to Here..."
						   action: @selector(saveTranscript:)
					keyEquivalent: @""];
	
	// Return the menu
	return [contextMenu autorelease];
}

// = Menu actions =

- (IBAction) playToHere: (id) sender {
	[self playToPoint: contextItem];
}

- (IBAction) showInTranscript: (id) sender {
	[self transcriptButtonClicked: nil
						 withItem: contextItem];
}

- (IBAction) addAnnotation: (id) sender {
	[self editItemAnnotation: contextItem];
}

- (IBAction) toggleLock: (id) sender {
	[contextItem setTemporary: ![contextItem temporary]];
}

- (IBAction) toggleLockBranch: (id) sender {
	[contextItem setBranchTemporary: ![contextItem temporary]];
}

- (IBAction) addNewBranch: (id) sender {
	// Add a new, blank item
	ZoomSkeinItem* newItem = [contextItem addChild: [ZoomSkeinItem skeinItemWithCommand: @""]];
	
	// Lock it
	[newItem setTemporary: NO];
	
	// Note the changes
	[skein zoomSkeinChanged];	
	[self skeinNeedsLayout];
	
	// Edit the item
	[self scrollToItem: newItem];
	[self editItem: newItem];
}

- (IBAction) insertItem: (id) sender {
	// Get the parent item
	ZoomSkeinItem* parent = [contextItem parent];
	
	// Remove any child items (these will become children of the new item)
	NSArray* children = [[[[parent children] allObjects] copy] autorelease];
	ZoomSkeinItem* child;
	NSEnumerator* childEnum = [children objectEnumerator];;
	
	while (child = [childEnum nextObject]) {
		[parent removeChild: child];
	}
	
	// Add a new, blank item
	ZoomSkeinItem* newItem = [parent addChild: [ZoomSkeinItem skeinItemWithCommand: @""]];
	
	// Add the child items back in again
	childEnum = [children objectEnumerator];;
	
	while (child = [childEnum nextObject]) {
		[newItem addChild: child];
	}
	
	// Lock it
	[newItem setTemporary: NO];
	
	// Note the changes
	[skein zoomSkeinChanged];	
	[self skeinNeedsLayout];
	
	// Edit the item
	[self scrollToItem: newItem];
	[self editItem: newItem];
}

- (BOOL) checkDelete: (ZoomSkeinItem*) skeinItem {
	ZoomSkeinItem* itemParent = [skeinItem parent];
	
	if (itemParent == nil) return NO;
	
	ZoomSkeinItem* parent = [skein activeItem];
	while (parent != nil) {
		if (parent == skeinItem) {
			if (![delegate respondsToSelector: @selector(cantDeleteActiveBranch)]) {
				// Can't delete an item that's the parent of the active item
				NSBeep();
			} else {
				[delegate cantDeleteActiveBranch];
			}
			return NO;
		}
		
		parent = [parent parent];
	}
	
	return YES;
}

- (IBAction) deleteItem: (id) sender {
	if (![self checkDelete: contextItem]) return;
	
	ZoomSkeinItem* parent = [contextItem parent];
	[parent removeChild: contextItem];
	
	// Force a layout of the skein
	[self scrollToItem: parent];
	[skein zoomSkeinChanged];
	[self skeinNeedsLayout];
}

- (IBAction) deleteOneItem: (id) sender {
	if (![self checkDelete: contextItem]) return;

	// Remember the children of this item
	NSArray* children = [[[[contextItem children] allObjects] copy] autorelease];

	// Remove them from the tree
	ZoomSkeinItem* child;
	NSEnumerator* childEnum = [children objectEnumerator];;
	
	while (child = [childEnum nextObject]) {
		[contextItem removeChild: child];
	}
	
	// Remove this item (and any children)
	ZoomSkeinItem* parent = [contextItem parent];
	[parent removeChild: contextItem];
	
	// Add the children back to the parent item
	childEnum = [children objectEnumerator];;
	
	while (child = [childEnum nextObject]) {
		[parent addChild: child];
	}
	
	// Force a layout of the skein
	[skein zoomSkeinChanged];
	[self skeinNeedsLayout];
	
	// Force a layout of the skein
	[self scrollToItem: parent];
	[skein zoomSkeinChanged];
	[self skeinNeedsLayout];
}

- (IBAction) deleteBranch: (id) sender {
	if (![self checkDelete: contextItem]) return;

	// Find the top of this branch
	ZoomSkeinItem* top = contextItem;
	
	while (top != nil && [top parent] != [skein rootItem] && [[[top parent] children] count] <= 1) {
		top = [top parent];
	}
	
	if (![self checkDelete: top]) return;
	
	// Remove the entire branch
	ZoomSkeinItem* parent = [top parent];
	[parent removeChild: top];
	
	// Force a layout of the skein
	[self scrollToItem: parent];
	[skein zoomSkeinChanged];
	[self skeinNeedsLayout];
}

- (void) saveTranscript: (id) sender {
	if ([self window] == nil) return;
	
	NSSavePanel* panel = [NSSavePanel savePanel];
	[panel setAllowedFileTypes: [NSArray arrayWithObject:@"txt"]];
	
	NSURL* directoryURL = nil;
	if (directoryURL == nil) {
		directoryURL = [NSURL URLWithString: [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomTranscriptURL"]];
	}
	if (directoryURL == nil) {
		directoryURL = [NSURL fileURLWithPath: NSHomeDirectory()];
	}

    [panel setDirectoryURL: directoryURL];

    // Show it
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode)
     {
        if (returnCode != NSOKButton) return;

         NSString* data = [skein transcriptToPoint: contextItem];

         // Remember the directory we last saved in
         if ( [[panel directoryURL] path] != nil ) {
            [[NSUserDefaults standardUserDefaults] setObject: [[panel directoryURL] absoluteString]
                                                      forKey: @"ZoomTranscriptURL"];
         }

         // Save the data
         NSData* stringData = [data dataUsingEncoding: NSUTF8StringEncoding];
         [stringData writeToURL: [panel URL]
                     atomically: YES];
     }];
}

@end
