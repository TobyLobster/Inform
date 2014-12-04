//
//  IFTranscriptLayout.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 13/05/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFTranscriptLayout.h"


@implementation IFTranscriptLayout

// = Initialisation =

- (id) init {
	self = [super init];
	
	if (self) {
		// Look out for SkeinItem notifications
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(skeinItemChanged:)
													 name: ZoomSkeinItemHasChanged
												   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(skeinItemHasNewChild:)
													 name: ZoomSkeinItemHasNewChild
												   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(skeinItemBeingReplaced:)
													 name: ZoomSkeinItemIsBeingReplaced
												   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(skeinItemHasBeenRemoved:)
													 name: ZoomSkeinItemHasBeenRemovedFromTree
												   object: nil];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[transcriptItems makeObjectsPerformSelector: @selector(setDelegate:)
									 withObject: nil];

	[skein release];
	[targetItem release];
	[transcriptItems release];
	[itemMap release];
	
	[super dealloc];
}

// = Setting the skein and the item we're transcripting to =

- (void) setSkein: (ZoomSkein*) newSkein {
	// Clear out the old
	[self cancelLayout];
	
	[skein release]; skein = nil;
	[targetItem release]; targetItem = nil;
	[transcriptItems makeObjectsPerformSelector: @selector(finishEditing:)
									 withObject: nil];
	[transcriptItems makeObjectsPerformSelector: @selector(setDelegate:)
									 withObject: nil];
	[transcriptItems release]; transcriptItems = nil;
    
    // Carefully delete itemMap
    NSMutableDictionary* temp = itemMap;
    itemMap = nil;
	[temp release]; temp = nil;
	layoutPosition = 0;
	
	// Bring in the new
	skein = [newSkein retain];
}

- (ZoomSkein*) skein {
	return skein;
}

- (void) addSkeinItem: (ZoomSkeinItem*) item
				atEnd: (BOOL) atEnd {
	// Create the transcript item
	IFTranscriptItem* transItem = [[IFTranscriptItem alloc] init];
	
	[transItem setWidth: width];
	[transItem setCommand: [item command]];
	[transItem setTranscript: [item result]];
	[transItem setExpected: [item commentary]];
	
	[transItem setPlayed: [item played]];
	[transItem setChanged: [item changed]];
	
	[transItem setSkein: skein];
	[transItem setSkeinItem: item];
	[transItem setDelegate: self];
	
	// Add to the set of items	
	if (!atEnd) {
		[transcriptItems insertObject: transItem
							  atIndex: 0];
	} else {
		[transcriptItems addObject: transItem];
	}
	
	// Add an itemMap object
	[itemMap setObject: transItem
				forKey: [NSValue valueWithPointer: item]];

	[transItem release];
}

- (void) transcriptToPoint: (ZoomSkeinItem*) point {
	if ([itemMap objectForKey: [NSValue valueWithPointer: point]] != nil) {
		// Transcript already contains this item: do nothing
		return;
	}
	
	// Save ourselves some effort if point's parent already exists in the transcript (quite a common case)
	if ([point parent] != nil && [itemMap objectForKey: [NSValue valueWithPointer: [point parent]]] != nil) {
		IFTranscriptItem* finalItem = [itemMap objectForKey: [NSValue valueWithPointer: [point parent]]];
		
		if (finalItem == nil) NSLog(@"BUG: gweeble fweeble feep?");					// Should never happen
		
		int finalItemIndex = [transcriptItems indexOfObjectIdenticalTo: finalItem];
		
		if (finalItemIndex == NSNotFound) {
			// Might happen if something breaks
			NSLog(@"BUG: found an item in the item map but not in the list of transcript items");
			return;
		}
		
		// Remove all items after the final item
		while ([transcriptItems count] > finalItemIndex + 1) {
			IFTranscriptItem* dyingItem = [transcriptItems lastObject];
			
            NSValue* key = [NSValue valueWithPointer: [dyingItem skeinItem]];
            
			[itemMap removeObjectForKey: key];
			[[transcriptItems lastObject] finishEditing: self];
			[transcriptItems removeLastObject];
		}
		
		// Add point and any likely-looking child items
		ZoomSkeinItem* newItem = point;
		do {
			[self addSkeinItem: newItem
						 atEnd: YES];
			
			NSSet* childItems = [newItem children];
			if ([childItems count] == 1) {
				newItem = [[childItems allObjects] objectAtIndex: 0];
			} else {
				newItem = nil;
			}
		} while (newItem != nil);
		
		// Notify the delegate
		needsLayout = YES;
		[self transcriptHasUpdatedItems: NSMakeRange(finalItemIndex, [transcriptItems count] - finalItemIndex)];
		
		return;
	}
	
	// Delete the old transcript items
	[self cancelLayout];

	[targetItem release]; targetItem = nil;
	[transcriptItems makeObjectsPerformSelector: @selector(finishEditing:)
									 withObject: self];
	[transcriptItems makeObjectsPerformSelector: @selector(setDelegate:)
									 withObject: nil];
	[transcriptItems release]; transcriptItems = nil;

    // Delete itemMap carefully, this release causes notifications that access itemMap
    NSMutableDictionary* temp = itemMap;
    itemMap = nil;
	[temp release]; temp = nil;
	layoutPosition = 0;
	height = 0;
	
	// Create new transcript items
	transcriptItems = [[NSMutableArray alloc] init];
	itemMap = [[NSMutableDictionary alloc] init];
	targetItem = [point retain];
	
	// Move up the tree until we get to the root	
	ZoomSkeinItem* item = point;
	
	while (item != nil) {
		[self addSkeinItem: item
					 atEnd: NO];
		
		item = [item parent];
	}
	
	// Move down the tree for as long as there's a clear path
	item = point;
	while ([[item children] count] == 1) {
		// Move down the tree
		item = [[[item children] allObjects] objectAtIndex: 0];

		// Create the transcript item
		[self addSkeinItem: item
					 atEnd: YES];
	}
	
	// Start laying out the new items
	needsLayout = YES;
	
	// Notify the delegate
	[self transcriptHasUpdatedItems: NSMakeRange(0, [transcriptItems count])];
}

- (void) setWidth: (float) newWidth {
	if (newWidth == width) return;
	
	width = newWidth;
	
	for( IFTranscriptItem* item in transcriptItems ) {
		[item setWidth: width];
	}
	
	needsLayout = YES;
	layoutPosition = 0;
	height = 0;
}

- (float) height {
	return height;
}

- (void) blessAll {
	for( IFTranscriptItem* item in transcriptItems ) {
		[[item skeinItem] setCommentary: [[item skeinItem] result]];
	}
}

// = The delegate =

- (void) setDelegate: (id) newDelegate {
	delegate = newDelegate;
}

- (id) delegate {
	return delegate;
}

- (void) transcriptHasUpdatedItems: (NSRange) itemRange {
	if (delegate && [delegate respondsToSelector: @selector(transcriptHasUpdatedItems:)]) {
		[delegate transcriptHasUpdatedItems: itemRange];
	}
}

// = Item delegate functions =

- (void) transcriptItemHasChanged: (IFTranscriptItem*) item {
	// Find which item has changed
	int itemIndex = [transcriptItems indexOfObjectIdenticalTo: item];
	
	if (itemIndex == NSNotFound) return;
	
	// Update the offsets if necessary
	int updateItem;
	NSRange updateRange = NSMakeRange(itemIndex, 1);
	
	if ([item calculated]) {
		if ([item offset] + [item height] > height) height = [item offset] + [item height];
			
		IFTranscriptItem* lastItem = item;
		for (updateItem = itemIndex+1; updateItem < [transcriptItems count]; updateItem++) {
			IFTranscriptItem* thisItem = [transcriptItems objectAtIndex: updateItem];
			
			float newOffset = [lastItem offset] + [lastItem height];
			
			// Stop here if this item's offset is same as before
			if (newOffset == [thisItem offset]) break;
			
			// Update the offset
			[thisItem setOffset: newOffset];
			updateRange.length++;
			
			// Update the height if required
			if (newOffset + [thisItem height] > height) height = newOffset + [thisItem height];
			
			// Next item
			lastItem = thisItem;
		}
	}
	
	// Reduce the height (if required)
	IFTranscriptItem* lastItem = [transcriptItems lastObject];
	if ([lastItem calculated]) {
		float newHeight = floorf([lastItem offset] + [lastItem height]);
		
		if (newHeight != height) height = newHeight;
	}
	
	// Notify our delegate
	[self transcriptHasUpdatedItems: updateRange];
}

// = Skein item notifications =

- (void) skeinItemChanged: (NSNotification*) not {
	// Get the item, if it's in the transcript
	IFTranscriptItem* item = [itemMap objectForKey: [NSValue valueWithPointer: [not object]]];
	if (item == nil || [item updating]) return;
		
	// Update the item
	ZoomSkeinItem* skeinItem = [not object];
	int index = [transcriptItems indexOfObjectIdenticalTo: item];
	
	if (index == NSNotFound) {
		NSLog(@"BUG: found an item that's being changed in the map, but not in the list of transcript items");
		return;
	}
	
	[item setCommand: [skeinItem command]];
	[item setTranscript: [skeinItem result]];
	[item setExpected: [skeinItem commentary]];
	
	[item setPlayed: [skeinItem played]];
	[item setChanged: [skeinItem changed]];
	
	// Update ourselves
	[item calculateItem];
	[self transcriptItemHasChanged: item];
}

- (void) skeinItemHasNewChild: (NSNotification*) not {
	// Get the item, if it's in the transcript
	IFTranscriptItem* item = [itemMap objectForKey: [NSValue valueWithPointer: [not object]]];
	if (item == nil) return;
	
	// If the item is the last item in the transcript, then add this item to the transcript
	if (item == [transcriptItems lastObject]) {	
		ZoomSkeinItem* child = [[not userInfo] objectForKey: ZoomSIChild];
		
		if (child) {
			[self addSkeinItem: child
						 atEnd: YES];
			[[transcriptItems lastObject] calculateItem];
			
			// Will update the height etc as a side-effect (as the offset is set incorrectly in the new item)
			[self transcriptItemHasChanged: item];
		}
	}
}

- (void) skeinItemBeingReplaced: (NSNotification*) not {
	// Get the item, if it's in the transcript
	IFTranscriptItem* item = [itemMap objectForKey: [NSValue valueWithPointer: [not object]]];
	if (item == nil) return;
	
	// I don't think this ever actually happens for items that have made it as far as the transcript.
	NSLog(@"BUG: transcript is a bit wibbly");
}

- (void) skeinItemHasBeenRemoved: (NSNotification*) not {
	// Get the item, if it's in the transcript
	IFTranscriptItem* item = [itemMap objectForKey: [NSValue valueWithPointer: [not object]]];
	if (item == nil) return;
	
	// Remove the item (and the following items)
	int index = [transcriptItems indexOfObjectIdenticalTo: item];
	
	if (index == NSNotFound) {
		NSLog(@"BUG: found an item that's being removed in the map, but not in the list of transcript items");
		return;
	}
	
	if (index == 0) {
		NSLog(@"BUG: root item being removed (?!)");
		return;
	}
	
	while ([transcriptItems count] > index) {
		IFTranscriptItem* dyingItem = [transcriptItems objectAtIndex: index];
		
		[itemMap removeObjectForKey: [NSValue valueWithPointer: [dyingItem skeinItem]]];
		[[transcriptItems objectAtIndex: index] finishEditing: self];
		[transcriptItems removeObjectAtIndex: index];
	}
	
	[self transcriptItemHasChanged: [transcriptItems lastObject]];
}

// = Performing the layout =

- (void) runLayout {
	needsLayout = NO;
	
	// Actually performs the layout
	if (!layoutRunning) return;
	
	layoutRunning = NO;
	
	// Run through the items from the last one we laid out to find the first one that hasn't been laid out properly
	while (layoutPosition < [transcriptItems count] && [[transcriptItems objectAtIndex: layoutPosition] calculated]) {
		layoutPosition++;
	}
	
	// Give up if we're at the end
	if (layoutPosition >= [transcriptItems count]) {
		return;
	}
	
	// Lay out a maximum of 10 items
	int numberLaidOut = 0;
	int firstItem = layoutPosition;
	while (numberLaidOut < 10 && layoutPosition < [transcriptItems count]) {
		IFTranscriptItem* item = [transcriptItems objectAtIndex: layoutPosition];
		
		// Calculate the item
		[item calculateItem];
		
		// Calculate where it appears in the transcript
		if (layoutPosition > 0) {
			IFTranscriptItem* lastItem = [transcriptItems objectAtIndex: layoutPosition-1];
			[item setOffset: [lastItem offset] + [lastItem height]];
		} else {
			[item setOffset: 0];
		}
		
		// Calculate the transcript height
		float newHeight = [item offset] + [item height];
		if (newHeight > height) height = newHeight;
		
		// Move on
		layoutPosition++;
		numberLaidOut++;
	}
	
	// Inform the delegate
	[self transcriptHasUpdatedItems: NSMakeRange(firstItem, numberLaidOut)];
	
	// Give up if we're at the end
	if (layoutPosition >= [transcriptItems count]) return;
	
	// Queue up the next layout event
	needsLayout = YES;
	layoutRunning = YES;
	
	[self performSelector: @selector(runLayout)
			   withObject: nil 
			   afterDelay: 0.005
				  inModes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
}

- (BOOL) needsLayout {
	return needsLayout && !layoutRunning;
}

- (void) startLayout {
	// Queues up the layout in the background
	if (!layoutRunning) {
		layoutRunning = YES;
		layoutPosition = 0;
		
		[self runLayout];
	}
}

- (void) cancelLayout {
	if (layoutRunning) {
		layoutRunning = NO;
		
		[NSObject cancelPreviousPerformRequestsWithTarget: self];
	}
}

// = Getting items to draw =

- (NSArray*) itemsInRect: (NSRect) rect {
	int itemNum;
	IFTranscriptItem* item = nil;
	
	for (itemNum = 0; itemNum < [transcriptItems count]; itemNum++) {
		item = [transcriptItems objectAtIndex: itemNum];
		
		if (![item calculated]) continue;
		if ([item offset] + [item height] > rect.origin.y) break;
	}
	
	NSMutableArray* res = [NSMutableArray array];
	for (; itemNum < [transcriptItems count]; itemNum++) {
		item = [transcriptItems objectAtIndex: itemNum];
		
		if (![item calculated]) break;
		if ([item offset] > NSMaxY(rect)) break;
		
		[res addObject: item];
	}
	
	return res;
}

- (IFTranscriptItem*) itemForItem: (ZoomSkeinItem*) skeinItem {
	int index;
	int firstCalculated = NSNotFound;
	
	for (index=0; index<[transcriptItems count]; index++) {
		IFTranscriptItem* item = [transcriptItems objectAtIndex: index];
		
		// Calculate the item if necessary
		if (![item calculated]) {
			firstCalculated = index;
			
			[item calculateItem];
			
			if (index == 0) {
				[item setOffset: 0];
			} else {
				IFTranscriptItem* lastItem = [transcriptItems objectAtIndex: index-1];
				
				float newOffset = [lastItem offset] + [lastItem height];
				[item setOffset: newOffset];
				
				if (newOffset + [item height] > height) height = newOffset + [item height];
			}
		}
		
		if ([item skeinItem] == skeinItem) {
			// Found the item
			if (firstCalculated != NSNotFound) {
				[self transcriptHasUpdatedItems: NSMakeRange(firstCalculated, index-firstCalculated+1)];
			}
			
			return item;
		}
	}
	
	if (firstCalculated != NSNotFound) {
		[self transcriptHasUpdatedItems: NSMakeRange(firstCalculated, index-firstCalculated)];
	}
	
	return nil;
}

- (float) offsetOfItem: (ZoomSkeinItem*) skeinItem {
	IFTranscriptItem* item = [self itemForItem: skeinItem];
	
	if (item)
		return [item offset];
	else
		return -1;
}

- (float) heightOfItem: (ZoomSkeinItem*) skeinItem {
	IFTranscriptItem* item = [self itemForItem: skeinItem];
	
	if (item) 
		return [item height];
	else
		return -1;
}

// = Items relative to other items =

- (IFTranscriptItem*) lastChanged: (IFTranscriptItem*) item {
	// Find the item
	int itemIndex = [transcriptItems indexOfObjectIdenticalTo: item];
	if (itemIndex == NSNotFound || itemIndex < 0) return nil;
	
	itemIndex--;
	
	// Find the last changed item
	for (;itemIndex>=0; itemIndex--) {
		if ([[[transcriptItems objectAtIndex: itemIndex] skeinItem] changed]) 
			return [transcriptItems objectAtIndex: itemIndex];
	}
	
	// Nothing found
	return nil;
}

- (IFTranscriptItem*) nextChanged: (IFTranscriptItem*) item {
	// Find the item
	int itemIndex = [transcriptItems indexOfObjectIdenticalTo: item];
	if (itemIndex == NSNotFound || itemIndex < 0) return nil;
	
	itemIndex++;
	
	// Find the next changed item
	for (;itemIndex<[transcriptItems count]; itemIndex++) {
		if ([[[transcriptItems objectAtIndex: itemIndex] skeinItem] changed]) 
			return [transcriptItems objectAtIndex: itemIndex];
	}
	
	// Nothing found
	return nil;
}

- (IFTranscriptItem*) lastDiff: (IFTranscriptItem*) item {
	// Find the item
	int itemIndex = [transcriptItems indexOfObjectIdenticalTo: item];
	if (itemIndex == NSNotFound || itemIndex < 0) return nil;
	
	itemIndex--;
	
	// Find the last different item
	for (;itemIndex>=0; itemIndex--) {
		if ([[transcriptItems objectAtIndex: itemIndex] isDifferent]) 
			return [transcriptItems objectAtIndex: itemIndex];
	}
	
	// Nothing found
	return nil;
}

- (IFTranscriptItem*) nextDiff: (IFTranscriptItem*) item {
	// Find the item
	int itemIndex = [transcriptItems indexOfObjectIdenticalTo: item];
	if (itemIndex == NSNotFound || itemIndex < 0) return nil;
	
	itemIndex++;
	
	// Find the next different item
	for (;itemIndex<[transcriptItems count]; itemIndex++) {
		if ([[transcriptItems objectAtIndex: itemIndex] isDifferent]) 
			return [transcriptItems objectAtIndex: itemIndex];
	}
	
	// Nothing found
	return nil;
}

@end
