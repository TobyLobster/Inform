//
//  IFPageBarCell.h
//  Inform
//
//  Created by Andrew Hunter on 06/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
/// A cell that can be placed on the left or right of the IFPageBarView.
///
/// These cells can contain an image or text. Additionally, they can contain a drop-down menu or a pop-up
/// window. The assumption is that these will be rendered as part of the page bar view.
///
@interface IFPageBarCell : NSActionCell

/// Gets the identifier for this cell
@property (atomic, strong) id identifier;

/// Sets the key equivalent for this cell
- (void) setKeyEquivalent: (NSString*) keyEquivalent;

// Drawing the cell
/// Forces this cell to refresh
- (void) update;

// Acting as a pop-up
/// \c YES if this is a pop-up cell of some kind
@property (atomic, getter=isPopup, readonly) BOOL popup;
/// Request to run the pop-up
- (void) showPopupAtPoint: (NSPoint) pointInWindow;
/// The pop-up menu
- (void) setMenu: (NSMenu*) menu;

/// Acting as part of a radio group
@property (atomic) int radioGroup;

// Acting as a tab (you'll need to implement another control to make this work)
/// The view to display for this item
@property (atomic, strong) NSView *view;

@end

///
/// Optional methods that may be implemented by a cell in a page bar
///
@interface NSCell(IFPageBarCell)

/// Whether or not this cell is to be drawn on the right-hand side of the bar
- (void) setIsRight: (BOOL) isRight;

@end
