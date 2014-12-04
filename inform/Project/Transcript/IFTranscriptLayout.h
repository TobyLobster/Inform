//
//  IFTranscriptLayout.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 13/05/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomSkeinItem.h>
#import <ZoomView/ZoomSkein.h>

#import "IFTranscriptItem.h"

//
// Class that deals with laying out a transcript
//
@interface IFTranscriptLayout : NSObject {
	// Skein and the target item
	ZoomSkein* skein;									// The skein that this transcript refers to
	ZoomSkeinItem* targetItem;							// The 'target' item that we're transcripting to
	
	// The transcript items themselves
	NSMutableArray* transcriptItems;					// Transcript items in order
	float width;										// Width that has been set
	float height;										// Height that has been calculated
	
	NSMutableDictionary* itemMap;						// Maps NSValue(ZoomSkeinItem)s to IFTranscriptItems - used to quickly handle the skein item notifications
	
	// Running the layout
	BOOL needsLayout;									// YES if we need to be laid out again
	int layoutPosition;									// Position in the transcriptItems array that the layout has reached
	BOOL layoutRunning;									// YES if we're in the process of laying stuff out
	
	// The delegate
	id delegate;										// Is not retained
}

// Setting the skein and the item we're transcripting to
- (void)       setSkein: (ZoomSkein*) skein;					// Set the skein that we're getting items from
- (ZoomSkein*) skein;											// Retrieve the skein that we're getting items from

- (void) transcriptToPoint: (ZoomSkeinItem*) point;				// Develop the transcript to the given point

- (void) blessAll;												// 'Blesses' all the items in this transcript

// Performing the layout
- (BOOL) needsLayout;											// YES if this object needs layout and the layout has not begun
- (void) startLayout;											// Begins laying out the transcript
- (void) cancelLayout;											// Cancels any layout that's currently being performed

- (void) setWidth: (float) width;								// Sets the width of this layout

- (float) height;												// Retrieves the height of this layout

// Getting items to draw
- (NSArray*) itemsInRect: (NSRect) rect;						// Retrieves the items that would be in the given rectangle (goes by y-offset only)

- (IFTranscriptItem*) itemForItem: (ZoomSkeinItem*) skeinItem;	// Retrieves the IFTranscriptItem being used for a ZoomSkeinItem (calculating if necessary)
- (float) offsetOfItem: (ZoomSkeinItem*) item;					// Retrieves the offset for a specific item, calculating to that point if necessary
- (float) heightOfItem: (ZoomSkeinItem*) item;					// Retrieves the height of a specific item, calculating to that point if necessary

// Items relative to other items
- (IFTranscriptItem*) lastChanged: (IFTranscriptItem*) item;	// Retrieves the item that occurs before item and has the 'changed' flag set
- (IFTranscriptItem*) nextChanged: (IFTranscriptItem*) item;	// Retrieves the item that occurs after item and has the 'changed' flag set
- (IFTranscriptItem*) lastDiff: (IFTranscriptItem*) item;		// Retrieves the item that occurs after item and has a difference
- (IFTranscriptItem*) nextDiff: (IFTranscriptItem*) item;		// Retrieves the item that occurs after item and has a difference

// The delegate
- (void) setDelegate: (id) delegate;							// Delegate is not retained
- (id) delegate;												// Retrieves the delegate

@end

//
// Layout delegate functions
//
@interface NSObject(IFTranscriptLayoutDelegate)

- (void) transcriptHasUpdatedItems: (NSRange) itemRange;	// The layout has been performed for the specified items

@end
