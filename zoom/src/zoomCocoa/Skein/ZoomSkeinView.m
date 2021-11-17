//
//  ZoomSkeinView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jul 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>

#import "ZoomSkeinView.h"
#import "ZoomSkeinLayout.h"
#import "ZoomSkeinItem+Pasteboard.h"
#import "ZoomSkeinWeb.h"
#import "ZoomSkeinInternal.h"

#include <Carbon/Carbon.h>

// Constants
static const CGFloat defaultItemWidth = 120.0; // Pixels
static const CGFloat defaultItemHeight = 96.0;
static const CGFloat itemButtonBarWidth = 40.0;

// Images
static NSImage* add, *delete, *locked, *unlocked, *annotate, *transcript;

// Buttons
typedef NS_ENUM(NSInteger, ZSVbutton)
{
	ZSVnoButton = 0,
	ZSVaddButton,
	ZSVdeleteButton,
	ZSVlockButton,
	ZSVannotateButton,
	ZSVtranscriptButton,

	ZSVmainItem = 256
};

NSString* const ZoomSkeinItemPboardType = @"uk.org.logicalshift.zoom.skein.item";
NSString* const ZoomSkeinTranscriptURLDefaultsKey = @"ZoomTranscriptPath";

// Our sooper sekrit interface
@interface ZoomSkeinView()

// Layout
- (void) layoutSkein;
- (void) updateTrackingRects;
- (void) removeAllTrackingRects;

// UI
- (void) mouseEnteredView;
- (void) mouseLeftView;
- (void) mouseEnteredItem: (ZoomSkeinItem*) item;
- (void) mouseLeftItem: (ZoomSkeinItem*) item;

- (ZSVbutton) buttonUnderPoint: (NSPoint) point
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

@implementation ZoomSkeinView {
@private
	// Layout
	ZoomSkeinLayout* layout;
	
	// Cursor flags
	BOOL overWindow;
	BOOL overItem;
	
	NSMutableArray* trackingRects;
	NSMutableArray* trackingItems;
	ZoomSkeinItem* trackedItem;
	ZoomSkeinItem* clickedItem;
	
	// Dragging items
	BOOL    dragCanMove;

	// Drag scrolling
	BOOL    dragScrolling;
	NSPoint dragOrigin;
	NSRect  dragInitialVisible;
	
	// Clicking buttons
	NSInteger activeButton;
	NSInteger lastButton;
	
	/// Annoyingly poor support for tracking rects band-aid
	NSRect lastVisibleRect;
	
	// Editing things
	ZoomSkeinItem* itemToEdit;
	ZoomSkeinItem* mostRecentItem;
	NSScrollView* fieldScroller;
	NSTextView* fieldEditor;
	NSTextStorage* fieldStorage;
	
	BOOL editingAnnotation;
	
	CGFloat itemWidth;
	CGFloat itemHeight;
	
	// Context menu
	ZoomSkeinItem* contextItem;
}

+ (void) initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		add        = [[NSBundle bundleForClass: [self class]] imageForResource: @"SkeinAdd"];
		delete     = [[NSBundle bundleForClass: [self class]] imageForResource: @"SkeinDelete"];
		locked     = [[NSBundle bundleForClass: [self class]] imageForResource: @"SkeinLocked"];
		unlocked   = [[NSBundle bundleForClass: [self class]] imageForResource: @"SkeinUnlocked"];
		annotate   = [[NSBundle bundleForClass: [self class]] imageForResource: @"SkeinAnnotate"];
		transcript = [[NSBundle bundleForClass: [self class]] imageForResource: @"SkeinTranscript"];
	});
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
		
		[self registerForDraggedTypes: @[ZoomSkeinItemPboardType]];
    }
	
    return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Drawing

+ (void) drawButton: (NSImage*) button
			atPoint: (NSPoint) pt
		highlighted: (BOOL) highlight {
	NSRect imgRect;
	
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [button size];
	
	if (!highlight) {
		[button drawAtPoint: pt
				   fromRect: NSZeroRect
				  operation: NSCompositingOperationSourceOver
				   fraction: 1.0];
	} else {
		NSImage* highlighted = [[NSImage alloc] initWithSize: imgRect.size];
		
		[highlighted lockFocus];
		
		// Background
		[[NSColor colorWithSRGBRed: 0.0
							 green: 0.0
							  blue: 0.0
							 alpha: 0.4] set];
		NSRectFill(imgRect);
		
		// The item
		[button drawAtPoint: NSMakePoint(0,0)
				   fromRect: NSZeroRect
				  operation: NSCompositingOperationDestinationAtop
				   fraction: 1.0];
		
		[highlighted unlockFocus];
		
		// Draw
		[highlighted drawAtPoint: pt
						fromRect: imgRect
					   operation: NSCompositingOperationSourceOver
						fraction: 1.0];
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
		CGFloat xpos = [layout xposForItem: trackedItem];
		CGFloat ypos = ((CGFloat)[layout levelForItem: trackedItem])*itemHeight + (itemHeight / 2.0);
		CGFloat bgWidth =	[[trackedItem command] sizeWithAttributes: itemTextAttributes].width;
		
		// Layout is:
		//    A T        x +
		//    ( ** ITEM ** )
		//                 L
		// 
		// Where A = Annotate, T = transcript, x = delete, + = add, L = lock
		CGFloat w = bgWidth;
		if (w < itemButtonBarWidth) w = itemButtonBarWidth;
		w += 40.0;
		CGFloat left = xpos - w/2.0;
		CGFloat right = xpos + w/2.0;
		
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
			NSImage* lock = trackedItem.temporary?unlocked:locked;
			
			[[self class] drawButton: lock
							 atPoint: NSMakePoint(xpos - 8, ypos - 18)
						 highlighted: activeButton==ZSVlockButton];
		}
	}
}

- (BOOL) isFlipped {
	return YES;
}

#pragma mark - Setting/getting the source

@synthesize skein;

- (void) setSkein: (ZoomSkein*) sk {
	if (skein == sk) return;
	
	if (skein) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: ZoomSkeinChangedNotification
													  object: skein];
	}
	
	skein = sk;
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

#pragma mark - Laying things out

- (void) skeinDidChange: (__unused NSNotification*) not {
	[self finishEditing: self];
	[self skeinNeedsLayout];
	
	[self scrollToItem: mostRecentItem];
	mostRecentItem = nil;
}

- (void)updateSkein:(__unused id)sender
{
	[self skeinNeedsLayout];
	[self setNeedsDisplay: YES];
}

- (void) skeinNeedsLayout {
	if (!skeinNeedsLayout) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(layoutSkein)
											 target: self
										   argument: nil
											  order: 8
											  modes: @[NSDefaultRunLoopMode, NSModalPanelRunLoopMode]];
		skeinNeedsLayout = YES;
	}
}

@synthesize itemWidth;

- (void) setItemWidth: (CGFloat) newItemWidth {
	if (newItemWidth < 16.0) newItemWidth = 16.0;
	if (newItemWidth == itemWidth) return;
	itemWidth = newItemWidth;
	
	[self skeinNeedsLayout];
}

@synthesize itemHeight;

- (void) setItemHeight: (CGFloat) newItemHeight {
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
	layout.itemWidth = itemWidth;
	layout.itemHeight = itemHeight;
	layout.rootItem = skein.rootItem;
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

#pragma mark - Affecting the display

- (void) scrollToItem: (ZoomSkeinItem*) item {
	if (item == nil) item = [skein activeItem];
	if ([self superview] == nil) return;
	
	mostRecentItem = item;
	
	if (skeinNeedsLayout) [self layoutSkein];
	
	ZoomSkeinLayoutItem* foundItem = [layout dataForItem: item];
	
	if (foundItem) {
		CGFloat xpos, ypos;
		
		xpos = [layout xposForItem: item];
		ypos = [layout levelForItem: item]*itemHeight + (itemHeight / 2);
		
		NSRect visRect = [self visibleRect];
		
		xpos -= visRect.size.width / 2.0;
		ypos -= visRect.size.height / 3.0;
		
		[self scrollPoint: NSMakePoint(floor(xpos), floor(ypos))];
	} else {
		NSLog(@"ZoomSkeinView: Attempt to scroll to nonexistent item");
	}
}

#pragma mark - Skein mouse sensitivity

- (void) removeAllTrackingRects {
	for (NSNumber* val in trackingRects) {
		[self removeTrackingRect: [val integerValue]];
	}
	
	trackingRects = [[NSMutableArray alloc] init];
	
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
	trackedItem = nil;

	int startLevel = floor(NSMinY(visibleRect) / itemHeight)-1;
	int endLevel = ceil(NSMaxY(visibleRect) / itemHeight);
	
	NSTrackingRectTag tag;
	BOOL inside = NO;

	int level;
	
	if (startLevel < 0) startLevel = 0;
	if (endLevel >= [layout levels]) endLevel = (int)([layout levels]-1);
	
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
		
	[trackingRects addObject: @(tag)];
	
	for (level = startLevel; level<=endLevel; level++) {
		for (ZoomSkeinItem* item in [layout itemsOnLevel: level]) {
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
							   userData: (__bridge void * _Nullable)(item)
						   assumeInside: inside];
			[trackingRects addObject: @(tag)];
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
	
	trackedItem = item;
	overItem = YES;
	
	if (trackedItem) {
		[self setNeedsDisplay: YES];
	}
}

- (void) mouseLeftItem: (__unused ZoomSkeinItem*) item {
	if (overItem) [NSCursor pop];
	if (trackedItem) [self setNeedsDisplay: YES];
	overItem = NO;
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

- (BOOL)acceptsFirstMouse:(__unused NSEvent *)theEvent {
	return YES;
}

- (BOOL) acceptsFirstResponder {
	return YES;
}

#pragma mark - Mouse handling

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
	
	clickedItem = realItem;
	
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
		
		dragCanMove = ![clickedItem hasChild: [skein activeItem]];
				
		NSPoint origin;
		
		origin.x = [layout xposForItem: clickedItem] - [layout widthForItem: clickedItem]/2.0 - 20.0;
		origin.y = ((CGFloat)[layout levelForItem: clickedItem])*itemHeight + (itemHeight/2.0);
		origin.y += 22.0;
		NSDraggingImageComponent *dragImg = [[NSDraggingImageComponent alloc] initWithKey:NSDraggingImageComponentIconKey];
		dragImg.contents = itemImage;
		NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:clickedItem];
		[dragItem setDraggingFrame:(NSRect){origin, itemImage.size} contents:dragImg];
		
		[self beginDraggingSessionWithItems: @[dragItem]
									  event: event
									 source: self];
	} else if (trackedItem != nil && lastButton != ZSVnoButton) {
		// If the cursor moves away from a button, then unhighlight it
		NSInteger lastActiveButton = activeButton;
		
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
		clickedItem = nil;
	}
	
	if (dragScrolling) {
		dragScrolling = NO;
		[NSCursor pop];
		
		[[NSRunLoop currentRunLoop] performSelector: @selector(updateTrackingRects)
											 target: self
										   argument: nil
											  order: 64
											  modes: @[NSDefaultRunLoopMode]];
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
					if ([event modifierFlags]&NSEventModifierFlagOption && [event clickCount] == 1) {
						// Clicking with the option key edits immediately
						[self editItem: trackedItem];
					} else if ([event modifierFlags]&NSEventModifierFlagCommand || [event clickCount] == 2) {
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

- (ZSVbutton) buttonUnderPoint: (NSPoint) point
						inItem: (ZoomSkeinItem*) item {
	// Calculate info about the location of this item
	CGFloat xpos = [layout xposForItem: item];
	CGFloat ypos = ((CGFloat)[layout levelForItem: item]) * itemHeight + (itemHeight/2.0);

	NSDictionary* fontAttrs = itemTextAttributes;
	
	NSSize size = [[item command] sizeWithAttributes: fontAttrs];

	CGFloat w = size.width; //[[item objectForKey: ZSwidth] floatValue];
	if (w < itemButtonBarWidth) w = itemButtonBarWidth;
	w += 40.0;
	CGFloat left = -w/2.0;
	CGFloat right = w/2.0;
	CGFloat lozengeRight = size.width/2.0;
	
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

#pragma mark - Item control buttons

- (void) addButtonClicked: (__unused NSEvent*) event
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

- (void) deleteButtonClicked: (__unused NSEvent*) event
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

- (void) lockButtonClicked: (__unused NSEvent*) event
				  withItem: (ZoomSkeinItem*) skeinItem {
	if ([skeinItem parent] == nil) return;

	if (skeinItem.temporary) {
		skeinItem.temporary = NO;
	} else {
		// Unlock this item and its children
		
		// itemsToProcess is a stack of items
		NSMutableArray* itemsToProcess = [NSMutableArray array];
		[itemsToProcess addObject: skeinItem];
		
		while ([itemsToProcess count] > 0) {
			ZoomSkeinItem* thisItem = [itemsToProcess lastObject];
			[itemsToProcess removeLastObject];
	
			[thisItem setTemporary: YES];
	
			for (ZoomSkeinItem* child in [thisItem children]) {
				[itemsToProcess addObject: child];
			}
		}
	}
	
	[self setNeedsDisplay: YES];
}

- (void) annotateButtonClicked: (__unused NSEvent*) event
					  withItem: (ZoomSkeinItem*) skeinItem {
	// Provide an editor for the annotation rather than the item
	[self editItemAnnotation: skeinItem];
}

- (void) transcriptButtonClicked: (__unused NSEvent*) event
						withItem: (ZoomSkeinItem*) skeinItem {
	if (![delegate respondsToSelector: @selector(transcriptToPoint:)]) {
		// Can't transcript to this point: delegate does not support it
		return;
	}
	
	[delegate transcriptToPoint: skeinItem];
}

#pragma mark - Editing items

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

- (void) cancelEditing: (__unused id) sender {
	[self setNeedsDisplay: YES];
	[fieldScroller removeFromSuperview];
	
	if (fieldEditor == nil) return;
	
	// Kill off the field editor
	[fieldEditor removeFromSuperview];
	[[self window] makeFirstResponder: self];
	
	fieldEditor = nil;
	
	itemToEdit = nil;
}

- (void)controlTextDidEndEditing:(__unused NSNotification *)aNotification {
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
	
	// (Or the annotation)
	if (annotation) itemFrame.origin.y -= 18;
	
	// Make sure the item is the right size
	CGFloat minItemWidth = itemWidth - 32.0;
	if (itemFrame.size.width < minItemWidth) {
		itemFrame.origin.x  -= (minItemWidth - itemFrame.size.width)/2.0;
		itemFrame.size.width = minItemWidth;
	}
	
	// 'overflow' border
	itemFrame = NSInsetRect(itemFrame, -2.0, -2.0);	
	
	itemFrame.origin.x = floor(itemFrame.origin.x);
	itemFrame.origin.y = floor(itemFrame.origin.y)-1.0;
	itemFrame.size.width = floor(itemFrame.size.width);
	itemFrame.size.height = floor(itemFrame.size.height);
	
	itemToEdit = skeinItem;
	
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
	
	fieldStorage = [[NSTextStorage alloc] initWithString: itemText
											  attributes: itemTextAttributes];	
	[fieldEditor.textStorage setAttributedString: fieldStorage];
	[fieldEditor setSelectedRange: NSMakeRange(0,0)];
	
	fieldEditor.delegate = self;
	fieldScroller.frame = itemFrame;
	fieldEditor.frame = NSInsetRect(itemFrame, 2.0, 2.0);
	
	fieldEditor.alignment = NSTextAlignmentCenter;
	fieldEditor.font = itemTextAttributes[NSFontAttributeName];
	
	fieldEditor.richText = NO;
	fieldEditor.allowsDocumentBackgroundColorChange = NO;
	fieldEditor.backgroundColor = NSColor.textBackgroundColor;
	
	fieldEditor.textContainer.size = NSMakeSize(NSInsetRect(itemFrame, 2.0, 2.0).size.width, 1e6);
	fieldEditor.textContainer.widthTracksTextView = NO;
	fieldEditor.textContainer.heightTracksTextView = NO;
	fieldEditor.horizontallyResizable = NO;
	fieldEditor.verticallyResizable = YES;
	fieldEditor.drawsBackground = YES;
	fieldEditor.editable = YES;
	
	// Activate it
	fieldScroller.documentView = fieldEditor;
	[self addSubview: fieldScroller];
	[self.window makeFirstResponder: fieldEditor];
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

#pragma mark - Selecting items

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

#pragma mark - Playing the game

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

#pragma mark - Delegate

@synthesize delegate;

#pragma mark - Moving around

- (void)viewWillMoveToWindow:(__unused NSWindow *)newWindow {
	[self finishEditing: self];
	[self removeAllTrackingRects];
}

- (void) viewWillMoveToSuperview:(__unused NSView *)newSuperview {
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

#pragma mark - NSDraggingSource protocol

-     (NSDragOperation)draggingSession: (NSDraggingSession *)session
 sourceOperationMaskForDraggingContext: (NSDraggingContext)context {
	if (context == NSDraggingContextWithinApplication) {
		if (dragCanMove) {
			return NSDragOperationCopy|NSDragOperationMove;
		} else {
			return NSDragOperationCopy;
		}
	} else {
		return NSDragOperationCopy;
	}
}

- (void)draggingSession: (NSDraggingSession *)session
		   endedAtPoint: (NSPoint)screenPoint
			  operation: (NSDragOperation)operation {
	if ((operation&NSDragOperationMove) && clickedItem != nil && dragCanMove) {
		[clickedItem removeFromParent];
		[self skeinNeedsLayout];
	}
}

#pragma mark - NSDraggingDestination protocol

- (NSDragOperation) updateDragCursor: (id <NSDraggingInfo>) sender {
	NSPoint dragPoint = [self convertPoint: [sender draggingLocation]
								  fromView: nil];
	ZoomSkeinItem* item = [layout itemAtPoint: dragPoint];
	
	if (item == nil || item == clickedItem || [item hasChildWithCommand: [clickedItem command]]) {
		[[NSCursor operationNotAllowedCursor] set];
		
		return NSDragOperationNone;
	} else {
		if ([sender draggingSourceOperationMask]&NSDragOperationMove &&
			![clickedItem hasChild: item]) {
			[[NSCursor arrowCursor] set];
			
			return NSDragOperationMove;
		} else {
			[[NSCursor dragCopyCursor] set];
			
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

- (void)draggingExited:(__unused id <NSDraggingInfo>)sender {
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
	
	ZoomSkeinItem* newItem = [NSKeyedUnarchiver unarchivedObjectOfClass: [ZoomSkeinItem class]
															   fromData: data
																  error: NULL];
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

#pragma mark - Context menu

- (NSMenu *)menuForEvent:(NSEvent *)event {
	NSBundle *ourBundle = [NSBundle bundleForClass: [self class]];
#define LocalizedSkeinString(key1, comment1) NSLocalizedStringFromTableInBundle(key1, @"LocalizedSkein", ourBundle, comment1)
	// Find which item that the mouse is over
	NSPoint pointInView = [event locationInWindow];
	pointInView = [self convertPoint: pointInView fromView: nil];
	
	contextItem = [layout itemAtPoint: pointInView];
	
	if (contextItem == nil) return nil;
	
	NSMenu* contextMenu = [[NSMenu alloc] init];
	
	// Add menu items for the standard actions
	
	[contextMenu addItemWithTitle: LocalizedSkeinString(@"Play to Here", @"Play to Here")
						   action: @selector(playToHere:)
					keyEquivalent: @""];
	
	[contextMenu addItem: [NSMenuItem separatorItem]];

	BOOL needSep = NO;
	if ([contextItem parent] != nil) {
		BOOL hasLabel = [[contextItem annotation] length] > 0;
		needSep = YES;
		NSString *newTitle;
		if (hasLabel) {
			newTitle = LocalizedSkeinString(@"Edit Label", @"Edit Label");
		} else {
			newTitle = LocalizedSkeinString(@"Add Label", @"Add Label");
		}
		[contextMenu addItemWithTitle: newTitle
							   action: @selector(addAnnotation:)
						keyEquivalent: @""];
	}
	if ([delegate respondsToSelector: @selector(transcriptToPoint:)]) {
		needSep = YES;
		[contextMenu addItemWithTitle: LocalizedSkeinString(@"Show in Transcript", @"Show in Transcript")
							   action: @selector(showInTranscript:)
						keyEquivalent: @""];
	}
	if ([contextItem parent] != nil) {
		needSep = YES;
		
		[contextMenu addItemWithTitle: contextItem.temporary ? LocalizedSkeinString(@"Lock", @"Lock") : LocalizedSkeinString(@"Unlock", @"Unlock")
							   action: @selector(toggleLock:)
						keyEquivalent: @""];
		[contextMenu addItemWithTitle: contextItem.temporary ? LocalizedSkeinString(@"Lock this Thread", @"Lock this Thread") : LocalizedSkeinString(@"Unlock this Branch", @"Unlock this Branch")
							   action: @selector(toggleLockBranch:)
						keyEquivalent: @""];
	}

	if (needSep) [contextMenu addItem: [NSMenuItem separatorItem]];

	if ([[contextItem children] count] > 0) {
		[contextMenu addItemWithTitle: LocalizedSkeinString(@"New Thread", @"New Thread")
							   action: @selector(addNewBranch:)
						keyEquivalent: @""];
	} else {
		[contextMenu addItemWithTitle: LocalizedSkeinString(@"Add New", @"Add New")
							   action: @selector(addNewBranch:)
						keyEquivalent: @""];
	}

	if ([contextItem parent] != nil) {
		[contextMenu addItemWithTitle: LocalizedSkeinString(@"Insert Knot", @"Insert Knot")
							   action: @selector(insertItem:)
						keyEquivalent: @""];
		if ([[contextItem children] count] > 0) {
			[contextMenu addItemWithTitle: LocalizedSkeinString(@"Delete", @"Delete")
								   action: @selector(deleteOneItem:)
							keyEquivalent: @""];
			[contextMenu addItemWithTitle: LocalizedSkeinString(@"Delete all Below", @"Delete all Below")
								   action: @selector(deleteItem:)
							keyEquivalent: @""];
		} else {
			[contextMenu addItemWithTitle: LocalizedSkeinString(@"Delete", @"Delete")
								   action: @selector(deleteItem:)
							keyEquivalent: @""];
		}
		[contextMenu addItemWithTitle: LocalizedSkeinString(@"Delete all in Thread", @"Delete all in Thread")
							   action: @selector(deleteBranch:)
						keyEquivalent: @""];
	}
	
	[contextMenu addItem: [NSMenuItem separatorItem]];
	[contextMenu addItemWithTitle: LocalizedSkeinString(@"Save Transcript to Here...", @"Save Transcript to Here...")
						   action: @selector(saveTranscript:)
					keyEquivalent: @""];
	
	// Return the menu
	return contextMenu;
#undef LocalizedSkeinString
}

#pragma mark - Menu actions

- (IBAction) playToHere: (__unused id) sender {
	[self playToPoint: contextItem];
}

- (IBAction) showInTranscript: (__unused id) sender {
	[self transcriptButtonClicked: nil
						 withItem: contextItem];
}

- (IBAction) addAnnotation: (__unused id) sender {
	[self editItemAnnotation: contextItem];
}

- (IBAction) toggleLock: (__unused id) sender {
	contextItem.temporary = !contextItem.temporary;
}

- (IBAction) toggleLockBranch: (__unused id) sender {
	[contextItem setBranchTemporary: !contextItem.temporary];
}

- (IBAction) addNewBranch: (__unused id) sender {
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

- (IBAction) insertItem: (__unused id) sender {
	// Get the parent item
	ZoomSkeinItem* parent = [contextItem parent];
	
	// Remove any child items (these will become children of the new item)
	NSArray* children = [[[parent children] allObjects] copy];
	
	for (ZoomSkeinItem* child in children) {
		[parent removeChild: child];
	}
	
	// Add a new, blank item
	ZoomSkeinItem* newItem = [parent addChild: [ZoomSkeinItem skeinItemWithCommand: @""]];
	
	// Add the child items back in again
	for (ZoomSkeinItem* child in children) {
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

- (IBAction) deleteItem: (__unused id) sender {
	if (![self checkDelete: contextItem]) return;
	
	ZoomSkeinItem* parent = [contextItem parent];
	[parent removeChild: contextItem];
	
	// Force a layout of the skein
	[self scrollToItem: parent];
	[skein zoomSkeinChanged];
	[self skeinNeedsLayout];
}

- (IBAction) deleteOneItem: (__unused id) sender {
	if (![self checkDelete: contextItem]) return;

	// Remember the children of this item
	NSArray* children = [[[contextItem children] allObjects] copy];

	// Remove them from the tree
	for (ZoomSkeinItem* child in children) {
		[contextItem removeChild: child];
	}
	
	// Remove this item (and any children)
	ZoomSkeinItem* parent = [contextItem parent];
	[parent removeChild: contextItem];
	
	// Add the children back to the parent item
	for (ZoomSkeinItem* child in children) {
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

- (IBAction) deleteBranch: (__unused id) sender {
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

- (void) saveTranscript: (__unused id) sender {
	if ([self window] == nil) return;
	
	NSSavePanel* panel = [NSSavePanel savePanel];
	panel.allowedFileTypes = @[(NSString*)kUTTypePlainText];
	
	NSURL* directory = nil;
	if (directory == nil) {
		directory = [[NSUserDefaults standardUserDefaults] URLForKey: ZoomSkeinTranscriptURLDefaultsKey];
	}
	if (directory == nil) {
		directory = [NSURL fileURLWithPath: NSHomeDirectory()];
	}
	
	if (directory) {
		panel.directoryURL = directory;
	}
	
	NSString *data = [skein transcriptToPoint: contextItem];
	[panel beginSheetModalForWindow: self.window completionHandler: ^(NSModalResponse result) {
		if (result != NSModalResponseOK) return;
		
		// Remember the directory we last saved in
		[[NSUserDefaults standardUserDefaults] setURL: [panel directoryURL]
											   forKey: ZoomSkeinTranscriptURLDefaultsKey];
		
		// Save the data
		[data writeToURL: [panel URL]
			  atomically: YES
				encoding: NSUTF8StringEncoding
				   error: NULL];
	}];
}

@end
