//
//  IFHeaderNode.h
//  Inform
//
//  Created by Andrew Hunter on 03/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFHeader.h"

NS_ASSUME_NONNULL_BEGIN

@class IFIntelFile;

typedef NS_ENUM(int, IFHeaderNodeSelectionStyle) {
    /// Node is unselected
	IFHeaderNodeUnselected,
    /// Node has been selected by the user
	IFHeaderNodeSelected,
    /// Node contains the input cursor
	IFHeaderNodeInputCursor
};

///
/// A single node in a header view
///
@interface IFHeaderNode : NSObject
// Constructing this node

/// Constructs a new header node
- (instancetype) initWithHeader: (IFHeader*) header
                       position: (NSPoint) position
                          depth: (int) depth;
/// Populates this node to the specified depth
- (void) populateToDepth: (int) maxDepth;

// Getting information about this node

/// The frame for this node
@property (atomic, readonly)                  NSRect                      frame;
/// The header associated with this node
@property (atomic, readonly, strong)          IFHeader *                  header;
/// The selection style of this node
@property (atomic)                            IFHeaderNodeSelectionStyle  selectionStyle;
/// The children associated with this node (nil if it has none)
@property (atomic, readonly, copy, nullable)  NSArray<IFHeaderNode*> *    children;

/// The node appearing at the specified point
- (nullable IFHeaderNode*) nodeAtPoint: (NSPoint) point
                           editableOut: (bool*) editableOut;
/// The best match for the node corresponding to the specified line numbers
- (nullable IFHeaderNode*) nodeWithLines: (NSRange) lines
							   intelFile: (nullable IFIntelFile*) intel;

/// The attributes for the title being displayed in this node
@property (atomic, readonly, copy) NSDictionary<NSAttributedStringKey,id> *attributes;
/// The background colour for the text in this node (nil if it's not selected)
@property (atomic, readonly, copy, nullable) NSColor *            textBackgroundColour;
/// The bounding rectangle for the editable part of the name
@property (atomic, readonly)                 NSRect               headerTitleRect;
/// The editable part of the title as an attributed string
@property (atomic, readonly, copy)           NSAttributedString * attributedTitle;

/// Is this node being edited?
@property (atomic, getter=isEditing) BOOL editing;
/// Given an edited title, returns the exact value that should be substituted in the source code
- (NSString*) freshValueForEditedTitle: (NSString*) edited;

// Drawing the node
/// Draws this node
- (void) drawNodeInRect: (NSRect) rect
			  withFrame: (NSRect) frame;

@end

NS_ASSUME_NONNULL_END
