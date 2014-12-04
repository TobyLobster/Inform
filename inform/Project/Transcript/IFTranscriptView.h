//
//  IFTranscriptView.h
//  Inform
//
//  Created by Andrew Hunter on 12/09/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFTranscriptLayout.h"

// The various buttons within an item
enum IFTranscriptButton {
	IFTranscriptNoButton,
	IFTranscriptButtonPlayToHere,
	IFTranscriptButtonShowKnot,
	IFTranscriptButtonBless
};

//
// The transcript view
//
@interface IFTranscriptView : NSView {
	// Laying out the view
	IFTranscriptLayout* layout;					// The layout manager that we're using
	
	IFTranscriptItem* activeItem;				// The item that's drawn with the 'active' (yellow) border
	IFTranscriptItem* highlightedItem;			// The item that's drawn with the 'highlighted' (blue) border
	
	// Clicking buttons
	IFTranscriptItem* clickedItem;				// The item where a button is in the process of being clicked (not retained)
	enum IFTranscriptButton clickedButton;		// The button within the item that's being clicked
	
	// The delegate
	id delegate;
}

// Retrieving the layout
- (IFTranscriptLayout*) transcriptLayout;

// Displaying specific items
- (void) scrollToItem: (ZoomSkeinItem*) item;				// Scrolls a specific item to be visible
- (void) setHighlightedItem: (ZoomSkeinItem*) item;			// Sets a specific item to be the 'highlighted' item
- (void) setActiveItem: (ZoomSkeinItem*) item;				// Sets a specific item to be the 'active' item

- (ZoomSkeinItem*) highlightedItem;							// Retrieves the currently highlighted item

// The delegate
- (void) setDelegate: (id) delegate;						// Sets the delegate (the delegate is not retained)

// Some actions we can perform
- (void) blessAll;											// Tells the layout to bless all of its items

@end

// The transcript view delegate
@interface NSObject(IFTranscriptViewDelegate)

- (void) transcriptPlayToItem: (ZoomSkeinItem*) itemToPlayTo;		// The 'play to here' button has been clicked for the specified item
- (void) transcriptShowKnot: (ZoomSkeinItem*) knot;					// The 'show knot' button has been clicked for the specified item
- (void) transcriptBless: (IFTranscriptItem*) itemToBless;			// The 'bless' button has been clicked for the specified item (has default behaviour)

@end
