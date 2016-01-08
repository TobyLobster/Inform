//
//  IFPageBarCell.h
//  Inform
//
//  Created by Andrew Hunter on 06/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//
// A cell that can be placed on the left or right of the IFPageBarView.
//
// These cells can contain an image or text. Additionally, they can contain a drop-down menu or a pop-up 
// window. The assumption is that these will be rendered as part of the page bar view.
//
@interface IFPageBarCell : NSActionCell

@property (atomic, strong) id identifier;					// Gets the identifier for this cell

- (void) setKeyEquivalent: (NSString*) keyEquivalent;       // Sets the key equivalent for this cell

// Drawing the cell
- (void) update;                                            // Forces this cell to refresh

// Acting as a pop-up
@property (atomic, getter=isPopup, readonly) BOOL popup;	// YES if this is a pop-up cell of some kind
- (void) showPopupAtPoint: (NSPoint) pointInWindow;         // Request to run the pop-up
- (void) setMenu: (NSMenu*) menu;                           // The pop-up menu

// Acting as part of a radio group                          // Sets this cell up as an on/off cell as part of a radio group
@property (atomic) int radioGroup;							// Retrieves the radio group for this cell

// Acting as a tab (you'll need to implement another control to make this work)
@property (atomic, strong) NSView *view;					// The view to display for this item

@end

//
// Optional methods that may be implemented by a cell in a page bar
//
@interface NSCell(IFPageBarCell)

- (void) setIsRight: (BOOL) isRight;					// Whether or not this cell is to be drawn on the right-hand side of the bar

@end
