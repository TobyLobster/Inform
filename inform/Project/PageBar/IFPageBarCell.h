//
//  IFPageBarCell.h
//  Inform
//
//  Created by Andrew Hunter on 06/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN


///
/// A cell that can be placed on the left or right of the IFPageBarView.
///
/// These cells can contain an image or text. The assumption is that these will be rendered as part of the
/// page bar view.
///
@interface IFPageBarCell : NSActionCell

/// Gets the identifier for this cell
@property (atomic, strong, nullable) id identifier;

/// Sets the key equivalent for this cell
- (void) setKeyEquivalent: (NSString*) keyEquivalent;

// Drawing the cell
/// Forces this cell to refresh
- (void) update;

/// Acting as part of a radio group
@property (atomic) int radioGroup;

@end

///
/// Optional methods that may be implemented by a cell in a page bar
///
@interface NSCell(IFPageBarCell)

/// Whether or not this cell is to be drawn on the right-hand side of the bar
- (void) setIsRight: (BOOL) isRight;

@end

NS_ASSUME_NONNULL_END
