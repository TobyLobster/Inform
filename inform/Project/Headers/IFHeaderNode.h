//
//  IFHeaderNode.h
//  Inform
//
//  Created by Andrew Hunter on 03/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFHeader.h"

@class IFIntelFile;

typedef enum IFHeaderNodeSelectionStyle {
	IFHeaderNodeUnselected,					// Node is unselected
	IFHeaderNodeSelected,					// Node has been selected by the user
	IFHeaderNodeInputCursor					// Node contains the input cursor
} IFHeaderNodeSelectionStyle;

//
// A single node in a header view
//
@interface IFHeaderNode : NSObject
// Constructing this node

- (instancetype) initWithHeader: (IFHeader*) header			// Constructs a new header node
                       position: (NSPoint) position
                          depth: (int) depth;
- (void) populateToDepth: (int) maxDepth;                   // Populates this node to the specified depth

// Getting information about this node

@property (atomic, readonly)          NSRect                      frame;			// The frame for this node
@property (atomic, readonly, strong)  IFHeader *                  header;			// The header associated with this node
@property (atomic)                    IFHeaderNodeSelectionStyle  selectionStyle;	// The selection style of this node
@property (atomic, readonly, copy)    NSArray *                   children;         // The children associated with this node

- (IFHeaderNode*) nodeAtPoint: (NSPoint) point
                  editableOut: (bool*) editableOut;     // The node appearing at the specified point
- (IFHeaderNode*) nodeWithLines: (NSRange) lines        // The best match for the node corresponding to the specified line numbers
					  intelFile: (IFIntelFile*) intel;

@property (atomic, readonly, copy) NSDictionary *       attributes;                 // The attributes for the title being displayed in this node
@property (atomic, readonly, copy) NSColor *            textBackgroundColour;		// The background colour for the text in this node
@property (atomic, readonly)       NSRect               headerTitleRect;            // The bounding rectangle for the editable part of the name
@property (atomic, readonly, copy) NSAttributedString * attributedTitle;			// The editable part of the title as an attributed string

- (void) setEditing: (BOOL) editing;                            // Sets whether or not this node is being edited
- (NSString*) freshValueForEditedTitle: (NSString*) edited;     // Given an edited title, returns the exact value that should be substituted in the source code

// Drawing the node
- (void) drawNodeInRect: (NSRect) rect          // Draws this node
			  withFrame: (NSRect) frame;

@end
