//
//  IFPageBarView.h
//  Inform
//
//  Created by Andrew Hunter on 01/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IFPageBarCell;

///
/// Class implementing the page bar view.
///
@interface IFPageBarView : NSControl

// = Drawing =

/// The unselected background image
+ (NSImage*) normalImage;
/// The image to show while the mouse is down over a cell
+ (NSImage*) highlightedImage;
/// The image to show when a cell is selected
+ (NSImage*) selectedImage;
/// The image that we use when the cell is selected and the graphite theme is in effect
+ (NSImage*) graphiteSelectedImage;

/// Draws (part of) the background image for this bar
+ (void) drawOverlay: (NSImage*) overlay
			  inRect: (NSRect) rect
		 totalBounds: (NSRect) bounds
			fraction: (CGFloat) fraction;

// = Managing cells =

/// Sets whether or not this page bar accepts keyboard input
- (void) setIsActive: (BOOL) isActive;

/// Sets the set of cells displayed on the left
- (void) setLeftCells: (NSArray*) leftCells;
/// Sets the set of cells displayed on the right
- (void) setRightCells: (NSArray*) rightCells;

/// Forces the cells to be measured and laid out appropriately for this control
- (void) layoutCells;

/// Last cell that was tracked by this control (eg, because the user clicked on it)
@property (atomic, readonly, weak) NSCell *lastTrackedCell;
/// Sets the state for the specified cell (deals with radio group changes: probably only useful for IFPageBarCell)
- (void) setState: (int) state
		  forCell: (IFPageBarCell*) cell;

@end
