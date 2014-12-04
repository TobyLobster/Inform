//
//  IFPageBarView.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 01/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//
// Class implementing the page bar view.
//
@class IFPageBarCell;
@interface IFPageBarView : NSControl {
	BOOL cellsNeedLayout;							// YES if we need to perform layout on the cells
	BOOL isActive;									// YES if this page accepts keyboard input
	
	NSMutableArray* leftCells;						// The cells that appear on the left of this view
	NSMutableArray* rightCells;						// The cells that appear on the right of this view
	
	NSMutableArray* leftLayout;						// Left-hand cell layout
	NSMutableArray* rightLayout;					// Right-hand cell layout
	
	NSCell* trackingCell;							// The cell that the mouse is down over
	NSRect trackingCellFrame;						// The bounds for the cell that the mouse is down over
}

// = Drawing =

+ (NSImage*) normalImage;							// The unselected background image
+ (NSImage*) highlightedImage;						// The image to show while the mouse is down over a cell
+ (NSImage*) selectedImage;							// The image to show when a cell is selected
+ (NSImage*) graphiteSelectedImage;					// The image that we use when the cell is selected and the graphite theme is in effect

+ (void) drawOverlay: (NSImage*) overlay			// Draws (part of) the background image for this bar
			  inRect: (NSRect) rect
		 totalBounds: (NSRect) bounds
			fraction: (float) fraction;

// = Managing cells =

- (void) setIsActive: (BOOL) isActive;				// Sets whether or not this page bar accepts keyboard input

- (void) setLeftCells: (NSArray*) leftCells;		// Sets the set of cells displayed on the left
- (void) setRightCells: (NSArray*) rightCells;		// Sets the set of cells displayed on the right

- (void) layoutCells;								// Forces the cells to be measured and laid out appropriately for this control

- (NSCell*) lastTrackedCell;						// Last cell that was tracked by this control (eg, because the user clicked on it)
- (void) setState: (int) state						// Sets the state for the specified cell (deals with radio group changes: probably only useful for IFPageBarCell)
		  forCell: (IFPageBarCell*) cell;

@end

#import "IFPageBarCell.h"