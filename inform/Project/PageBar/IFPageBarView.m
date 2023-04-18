//
//  IFPageBarView.m
//  Inform
//
//  Created by Andrew Hunter on 01/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFPageBarView.h"
#import "IFPageBarCell.h"

//
// Notes (in no particular order)
//
// There are a maximum of three separate animations that can be occuring at any one
// time:
//
// One or more cells can be animating between states
// The background can animate between states (inactive -> active)
// The left and right hand side can fade out when switching between cell sets
//
// Not sure if I'm going to implement all of these. The cell animations are presently
// the most important, followed by the background animations.
//

///
/// Object used to represent the layout of an individual cell
///
@interface IFPageCellLayout : NSObject

@end

@implementation IFPageCellLayout {
@public
    /// Offset from the left/right for this cell
    CGFloat position;
    /// Minimum size that this cell can be
    CGFloat minWidth;
    /// Actual size that this cell should be drawn at
    CGFloat width;
    /// If \c YES then this cell shouldn't be drawn
    BOOL hidden;

    /// The image for this cell
    NSImage* cellFirstImage;
    /// The image for this cell
    NSImage* cellImage;
    /// The image to animate from
    NSImage* animateFrom;
}


@end

#pragma mark - Constants

/// Margin to put on the right (to account for scrollbars, tabs, etc)
static const CGFloat rightMargin = 14.0;
/// Extra margin to put on the right when drawing the 'bar' image as opposed to the background
static const CGFloat tabMargin =  0.0;
/// Margin on the left and right until we actually draw the first cell
static const CGFloat leftMargin = 3.0;

@implementation IFPageBarView {
    /// YES if we need to perform layout on the cells
    BOOL cellsNeedLayout;
    /// YES if this page accepts keyboard input
    BOOL isActive;

    /// The cells that appear on the left of this view
    NSMutableArray<__kindof NSCell*>* leftCells;
    /// The cells that appear on the right of this view
    NSMutableArray<__kindof NSCell*>* rightCells;

    /// Left-hand cell layout
    NSMutableArray* leftLayout;
    /// Right-hand cell layout
    NSMutableArray* rightLayout;

    /// The cell that the mouse is down over
    __weak NSCell* trackingCell;
    /// The bounds for the cell that the mouse is down over
    NSRect trackingCellFrame;
}

#pragma mark - Images

+ (NSImage*) backgroundImage {
	static NSImage* image = nil;
	
	if (!image) {
		image = [NSImage imageNamed: @"App/PageBar/BarBackground"];
	}
	
	return image;
}

+ (NSImage*) normalImage {
	static NSImage* image = nil;
	
	if (!image) {
		image = [NSImage imageNamed: @"App/PageBar/BarNormal"];
	}
	
	return image;
}

+ (NSImage*) inactiveImage {
	static NSImage* image = nil;
	
	if (!image) {
		image = [NSImage imageNamed: @"App/PageBar/BarInactive"];
	}
	
	return image;
}

#pragma mark - Initialisation

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
		cellsNeedLayout = YES;
    }
	
    return self;
}


#pragma mark - Drawing

+ (void) drawOverlay: (NSColor*) overlay
			  inRect: (NSRect) rect
		 totalBounds: (NSRect) bounds
			fraction: (CGFloat) fraction {
	// Draws an overlay colour, given the bounds of this control and the area to draw
	rect = NSIntersectionRect(rect, bounds);

	if (rect.size.width > 0) {
		NSRect destRect = NSMakeRect(rect.origin.x, bounds.origin.y, rect.size.width, bounds.size.height);
		[overlay set];
		NSRectFillUsingOperation(destRect, NSCompositingOperationSourceOver);
		[NSColor.controlAccentColor set];
		NSRectFillUsingOperation(destRect, NSCompositingOperationOverlay);
	}
}

- (NSImage*) renderCell: (NSCell*) cell
			  forLayout: (IFPageCellLayout*) layout 
			    isRight: (BOOL) right
                isFirst: (BOOL) isFirst {
	// Render the specified cell using the specified layout
	NSRect bounds = [self bounds];
	
	bounds.origin.x += leftMargin;
	bounds.size.width -= leftMargin + tabMargin + rightMargin;
	
	// Set this cell to be owned by this view
	if ([cell controlView] != self) {
		//[cell setControlView: self];
		
		// Note that this makes it hard to move a cell from the left to the right
		if ([cell respondsToSelector: @selector(setIsRight:)]) {
			[cell setIsRight: right];
		}
	}

	// Construct the image that will contain this cell
	NSImage* cellImage = [[NSImage alloc] initWithSize: NSMakeSize(layout->width, bounds.size.height)];
	
	NSRect cellFrame = NSMakeRect(bounds.origin.x, bounds.origin.y, layout->width, bounds.size.height);
	if (right) {
		cellFrame.origin.x += bounds.size.width - layout->position - layout->width;
	} else {
		cellFrame.origin.x += layout->position;
	}
	
	// Prepare to draw the cell
	[cellImage lockFocus];
	
	NSAffineTransform* cellTransform = [NSAffineTransform transform];
	[cellTransform translateXBy: -cellFrame.origin.x
							yBy: -cellFrame.origin.y];
	[cellTransform concat];
	
	// Draw the cell
	[cell drawWithFrame: cellFrame
				 inView: self];
	
	// Draw the borders
	CGFloat marginLeftPos  = NSMinX(cellFrame)+0.5;
    CGFloat marginRightPos = NSMaxX(cellFrame)-0.5;
	
	[[[NSColor controlShadowColor] colorWithAlphaComponent: 0.4] set];
    
    if( right || isFirst) {
        [NSBezierPath strokeLineFromPoint: NSMakePoint(marginLeftPos, NSMinY(cellFrame)+1.5f)
                                  toPoint: NSMakePoint(marginLeftPos, NSMaxY(cellFrame))];
    }

    if( !right || isFirst ) {
        [NSBezierPath strokeLineFromPoint: NSMakePoint(marginRightPos, NSMinY(cellFrame)+1.5f)
                                  toPoint: NSMakePoint(marginRightPos, NSMaxY(cellFrame))];
    }
	
	// Finish drawing
	[cellImage unlockFocus];
	
	// Return the result
	return cellImage;
}

- (void) drawCellsFrom: (NSArray*) cellList
				layout: (NSArray*) layoutList
			 isOnRight: (BOOL) right {
	// Draw a set of suitably laid-out cells, either on the right or on the left
	NSEnumerator* cellEnum = [cellList objectEnumerator];
	NSEnumerator* layoutEnum = [layoutList objectEnumerator];
	NSCell* cell;
	IFPageCellLayout* layout;
	NSRect bounds = [self bounds];

	bounds.origin.x += leftMargin;
	bounds.size.width -= leftMargin + tabMargin + rightMargin;
	
    BOOL isFirst = YES;
    NSImage* cellImage = nil;
	while ((cell = [cellEnum nextObject]) && (layout = [layoutEnum nextObject])) {
		if (layout->hidden) continue;
		
		// Redraw the cell's cached images if required
        if( isFirst ) {
            cellImage = layout->cellFirstImage;
        }
        else {
            cellImage = layout->cellImage;
		}
        if (cellImage == nil) {
            cellImage = [self renderCell: cell
                               forLayout: layout
                                 isRight: right
                                 isFirst: isFirst];
        }

		// Draw the cell itself
		NSRect cellFrame = NSMakeRect(0,0, layout->width, bounds.size.height);
		NSRect cellSource = cellFrame;
		if (right) {
			cellFrame.origin.x = bounds.size.width - layout->position - layout->width;
		} else {
			cellFrame.origin.x = layout->position;
		}
		cellFrame.origin.x += bounds.origin.x;
		
		cellFrame.size.height -= 2; cellFrame.origin.y += 2;
		cellSource.size.height -= 2; cellSource.origin.y += 2;
				
		[cellImage drawInRect: NSIntegralRect(cellFrame)
                     fromRect: cellSource
                    operation: NSCompositingOperationSourceOver
                     fraction: ([cell isEnabled]?1.0:0.5) * (isActive?1.0:0.85)];
        isFirst = NO;
	}
}

- (void)drawRect:(NSRect)rect {
	// Update the cell positioning information
	[self layoutCells];

	// Draw the left-hand cells
	[self drawCellsFrom: leftCells
				 layout: leftLayout
			  isOnRight: NO];

	// Draw the right-hand cells
	[self drawCellsFrom: rightCells
				 layout: rightLayout
			  isOnRight: YES];

    // Draw single pixel horizontal line separating from main content
    NSRect fullRect = [self bounds];
    [[[NSColor controlShadowColor] colorWithAlphaComponent: 0.5f] set];
    [NSBezierPath strokeLineFromPoint: NSMakePoint(3.0f, 0.5f)
                              toPoint: NSMakePoint(fullRect.size.width - 14.0f, 0.5f)];

	return;
}

#pragma mark - Managing cells

- (void) setLeftCells: (NSArray*) newLeftCells {
	leftCells = [[NSMutableArray alloc] initWithArray: newLeftCells];
	
	 leftLayout = nil;
	cellsNeedLayout = YES;
	
	[self setNeedsDisplay: YES];
}

- (void) setRightCells: (NSArray*) newRightCells {
	rightCells = [[NSMutableArray alloc] initWithArray: newRightCells];
	
	 rightLayout = nil;
	cellsNeedLayout = YES;
	
	[self setNeedsDisplay: YES];
}

- (void) addCells: (NSMutableArray*) cells
		 toLayout: (NSMutableArray*) layout {
	CGFloat position = 0;
	for( NSCell* cell in cells ) {
		IFPageCellLayout* cellLayout = [[IFPageCellLayout alloc] init];
		
		cellLayout->position = position;
		cellLayout->minWidth = [cell cellSize].width;
		cellLayout->hidden = NO;
		
		if (position == 0 && [cell image]) {
			// Prevent images from looking a bit lopsided when right on the edge
			cellLayout->position -= 2;
			position -= 2;
		}

		cellLayout->width = cellLayout->minWidth;

		[layout addObject: cellLayout];
		position += cellLayout->width;
	}
}

- (void) layoutCells {
	if (!cellsNeedLayout) return;
	
	 leftLayout = nil;
	 rightLayout = nil;
	
	leftLayout = [[NSMutableArray alloc] init];
	rightLayout = [[NSMutableArray alloc] init];
	
	// First pass: add all cells to the left and right regardless of how wide they are
	// TODO: preserve cell images if at all possible
	[self addCells: leftCells
		  toLayout: leftLayout];
	[self addCells: rightCells
		  toLayout: rightLayout];
	
	// Second pass: reduce the width of any cell that can be shrunk
	//
	// TODO: But less important than:
	
	// Third pass: remove cells from the right, then from the left when there is
	// still not enough space
	NSRect bounds = [self bounds];
	
	bounds.origin.x += leftMargin;
	bounds.size.width -= leftMargin + tabMargin + rightMargin;

    CGFloat maxLeftPos = 0;
	if ([leftCells count] > 0) {
		IFPageCellLayout* lastLeftLayout = [leftLayout lastObject];
		maxLeftPos = lastLeftLayout->position + lastLeftLayout->width;
	}
	maxLeftPos += NSMinX(bounds);
	
	for( IFPageCellLayout* cellLayout in rightLayout ) {
		if (NSMaxX(bounds) - (cellLayout->position + cellLayout->width) <= maxLeftPos + 4) {
			cellLayout->hidden = YES;
		} else {
			cellLayout->hidden = NO;
		}
	}
	
	for( IFPageCellLayout* cellLayout in leftLayout ) {
		if (NSMinY(bounds) + (cellLayout->position + cellLayout->width) >= NSMaxX(bounds)-12) {
			cellLayout->hidden = YES;
		} else {
			cellLayout->hidden = NO;
		}
	}
}

- (void) setBounds: (NSRect) bounds {
	cellsNeedLayout = YES;
	[super setBounds: bounds];
}

- (void) setState: (int) state
		  forCell: (IFPageBarCell*) cell {
	// Set the cell state (the boring bit)
	[cell setState: state];
	
	// Get the radio group, and do nothing if this isn't a radio cell
	int group = [cell radioGroup];
	if (group < 0) {
		return;
	}
	
	// If we're not turning a cell on, then we don't need to do anything more
	if (state != NSControlStateValueOn) {
		return;
	}
	
	// Turn off any cells in the same group in the left or right groups

	for( NSCell* otherCell in leftCells ) {
		// Do nothing if this is the cell whose state is being set
		if (otherCell == cell) continue;
		
		// Do nothing if this cell is already turned off
		if ([otherCell state] == NSControlStateValueOff) continue;
		
		// Get the group for this cell
		int otherGroup = -1;
		if ([otherCell respondsToSelector: @selector(radioGroup)]) otherGroup = [(IFPageBarCell*)otherCell radioGroup];
		
		// If it's the same as the cell we're updating, then turn this cell off
		if (otherGroup == group) [otherCell setState: NSControlStateValueOff];
	}

	for( NSCell* otherCell in rightCells ) {
		// Do nothing if this is the cell whose state is being set
		if (otherCell == cell) continue;
		
		// Do nothing if this cell is already turned off
		if ([otherCell state] == NSControlStateValueOff) continue;
		
		// Get the group for this cell
		int otherGroup = -1;
		if ([otherCell respondsToSelector: @selector(radioGroup)]) otherGroup = [(IFPageBarCell*)otherCell radioGroup];
		
		// If it's the same as the cell we're updating, then turn this cell off
		if (otherGroup == group) [otherCell setState: NSControlStateValueOff];
	}
}

#pragma mark - Cell housekeeping

- (int) indexOfCellAtPoint: (NSPoint) point {
	// Returns 0 if no cell, a negative number for a right-hand cell or a positive number for a
	// left-hand cell

	// Update the cell layout
	if (cellsNeedLayout) [self layoutCells];

	// Work out the bounds for the cells
	NSRect bounds = [self bounds];
	
	bounds.origin.x += leftMargin;
	bounds.size.width -= leftMargin + tabMargin + rightMargin;
	
	// Not this cell if the rectangle is outside the bounds of this control
	if (point.y < NSMinY(bounds) || point.y > NSMaxY(bounds)) {
		return 0;
	}
	
	if (point.x < NSMinX(bounds)-4 || point.y > NSMaxX(bounds)+4) {
		return 0;
	}
	
	point.x -= NSMinX(bounds);
	
	// Search the left-hand cells
	NSEnumerator* cellEnum;
	NSEnumerator* layoutEnum;
	int index;
	NSCell* cell;
	IFPageCellLayout* layout;
	
	cellEnum = [leftCells objectEnumerator];
	layoutEnum = [leftLayout objectEnumerator];
	
	index = -1;
	while ((cell = [cellEnum nextObject]) && (layout = [layoutEnum nextObject])) {
		// Get the index for the cell we're about to process
		index++;
		
		// Ignore hidden cells
		if (layout->hidden) continue;
		
		// Test for a hit on this cell
		if ((index == 0 || point.x >= layout->position) && layout->position + layout->width >= point.x) {
			return index+1;
		}
	}
	
	// Search the right-hand cells
	cellEnum = [rightCells objectEnumerator];
	layoutEnum = [rightLayout objectEnumerator];
	
	index = -1;
	while ((cell = [cellEnum nextObject]) && (layout = [layoutEnum nextObject])) {
		// Get the index for the cell we're about to process
		index++;
		
		// Ignore hidden cells
		if (layout->hidden) continue;
		
		// Test for a hit on this cell
		if (point.x >= bounds.size.width - layout->position - layout->width 
			&& (index == 0 || bounds.size.width - layout->position >= point.x)) {
			return -(index+1);
		}
	}
	
	return 0;
}

- (NSRect) boundsForCellAtIndex: (NSUInteger) index
					  isOnRight: (BOOL) isRight {
	// Update the cell layout
	if (cellsNeedLayout) [self layoutCells];
	NSRect bounds = [self bounds];
	
	bounds.origin.x += leftMargin;
	bounds.size.width -= leftMargin + tabMargin + rightMargin;

	IFPageCellLayout* layout = (isRight?rightLayout:leftLayout)[index];	
	
	NSRect cellFrame = NSMakeRect(0,0, layout->width, bounds.size.height);
	if (isRight) {
		cellFrame.origin.x = bounds.size.width - layout->position - layout->width;
	} else {
		cellFrame.origin.x = layout->position;
	}
	cellFrame.origin.x += bounds.origin.x;
	
	return cellFrame;
}

- (void) updateCell: (NSCell*) aCell {
	// Update the cell layout
	if (cellsNeedLayout) [self layoutCells];
	
	NSUInteger cellIndex;
	NSMutableArray* layout = leftLayout;
	BOOL isRight = NO;
	
	// Find the cell in the left or right-hand collections
	cellIndex = [leftCells indexOfObjectIdenticalTo: aCell];
	if (cellIndex == NSNotFound) {
		layout = rightLayout;
		isRight = YES;
		cellIndex  = [rightCells indexOfObjectIdenticalTo: aCell];
	}
	
	// Do nothing if this cell is not part of this control
	if (cellIndex == NSNotFound) return;
	
	// Mark this cell as needing an update
	IFPageCellLayout* cellLayout = layout[cellIndex];
	cellLayout->cellImage = nil;
	
	// Refresh this cell
	NSRect bounds = [self boundsForCellAtIndex: cellIndex
									 isOnRight: isRight];
	
	if (cellIndex == 0) {
		// If on the left or right, then we also need to update the end caps
		if (isRight) {
			bounds.size.width = NSMaxX([self bounds])-bounds.origin.x;
		} else {
			NSRect viewBounds = [self bounds];
			bounds.size.width = NSMaxX(bounds)-NSMinX(viewBounds);
			bounds.origin.x = NSMinX(viewBounds);
		}
	}
	
	[self setNeedsDisplayInRect: bounds];
}

- (void)updateCellInside:(NSCell *)aCell {
	[self updateCell: aCell];
}

#pragma mark - Mouse events

@synthesize lastTrackedCell=trackingCell;

- (void) mouseDown: (NSEvent*) event {
	// Clear any tracking cell that might exist
	 trackingCell = nil;
	
	// Find which cell was clicked on
	int index = [self indexOfCellAtPoint: [self convertPoint: [event locationInWindow]
													fromView: nil]];
	BOOL isOnRight;
	if (index > 0) {
		// Left-hand cell was clicked
		isOnRight = NO;
		index--;
		
		trackingCell = leftCells[index];
	} else if (index < 0) {
		// Right-hand cell was clicked
		isOnRight = YES;
		index = (-index)-1;
		
		trackingCell = rightCells[index];
	} else {
		// No cell was clicked
		return;
	}
	
	trackingCellFrame = [self boundsForCellAtIndex: index
										 isOnRight: isOnRight];
	
	// Track the mouse
	BOOL trackResult = NO;
	NSEvent* trackingEvent = event;
	
	while (!trackResult) {
		if (![trackingCell isEnabled]) return;
		
		trackResult = [trackingCell trackMouse: trackingEvent
										inRect: trackingCellFrame
										ofView: self
								  untilMouseUp: NO];
		
		if (!trackResult) {
			// If the mouse is still down, continue tracking it in case it re-enters
			// the control
			while ((trackingEvent = [NSApp nextEventMatchingMask: NSEventMaskLeftMouseDragged|NSEventMaskLeftMouseUp
													  untilDate: [NSDate distantFuture]
														 inMode: NSEventTrackingRunLoopMode
														dequeue: YES])) {
				if ([trackingEvent type] == NSEventTypeLeftMouseUp) {
					// All finished
					return;
				} else if ([trackingEvent type] == NSEventTypeLeftMouseDragged) {
					// Restart tracking if the mouse has re-entered the cell
					NSPoint location = [self convertPoint: [trackingEvent locationInWindow]
												 fromView: nil];
					if (NSPointInRect(location, trackingCellFrame)) {
						break;
					}
				}
			}
		}
	}
}

#pragma mark - Keyboard events

- (void) setIsActive: (BOOL) newIsActive {
	if (isActive == newIsActive) return;
	
	
	isActive = newIsActive;
	[self setNeedsDisplay: YES];
	
}

- (BOOL) performKeyEquiv: (NSString*) equiv
				 onCells: (NSArray*) cells {
	for( NSCell* cell in cells ) {
		if ([[cell keyEquivalent] isEqualToString: equiv]) {
			[self sendAction: [cell action]
						  to: [cell target]];
			return YES;
		}
	}

	return NO;
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent {
	if (!isActive) return NO;
	
	// Cmd + back and Cmd + forward perform goForward and goBackwards actions in the 'current' view
	NSString* keyEquivString = [theEvent charactersIgnoringModifiers];
	
	if ([self performKeyEquiv: keyEquivString
					  onCells: leftCells])
		return YES;
	if ([self performKeyEquiv: keyEquivString
					  onCells: rightCells])
		return YES;
	
	return NO;
}

@end
