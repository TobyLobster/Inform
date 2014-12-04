//
//  IFHeaderNode.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 03/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFHeader.h"

typedef enum IFHeaderNodeSelectionStyle {
	IFHeaderNodeUnselected,					// Node is unselected
	IFHeaderNodeSelected,					// Node has been selected by the user
	IFHeaderNodeInputCursor					// Node contains the input cursor
} IFHeaderNodeSelectionStyle;

///
/// A single node in a header view
///
@interface IFHeaderNode : NSObject {
	NSPoint position;								// The position of this node
	NSRect frame;									// The frame for this node, including all it's children
	NSRect exclusiveFrame;							// The frame for this node, not including any children
	int depth;										// The depth of this node in the tree
	IFHeaderNodeSelectionStyle selected;			// The selection style of this node
	BOOL editing;									// YES if we're editing this node
	
	IFHeader* header;								// The IFHeader item associated with this node
	NSMutableArray* children;						// The child nodes of this node
	
	// Parameters representing how this node should be laid out
	float margin;									// Margin to the items
	float indent;									// Indentation per level
	float gap;										// Vertical gap around items
	float corner;									// Size of a corner for an item
}

// Constructing this node

- (id) initWithHeader: (IFHeader*) header			// Constructs a new header node
			 position: (NSPoint) position
				depth: (int) depth;
- (void) populateToDepth: (int) maxDepth;			// Populates this node to the specified depth

// Getting information about this node

- (NSRect) frame;									// The frame for this node
- (IFHeader*) header;								// The header associated with this node
- (IFHeaderNodeSelectionStyle) selectionStyle;		// The selection style of this node
- (void) setSelectionStyle: (IFHeaderNodeSelectionStyle) selectionStyle;
- (NSArray*) children;								// The children associated with this node
- (IFHeaderNode*) nodeAtPoint: (NSPoint) point
                  editableOut: (bool*) editableOut;	// The node appearing at the specified point
- (IFHeaderNode*) nodeWithLines: (NSRange) lines	// The best match for the node corresponding to the specified line numbers
					  intelFile: (IFIntelFile*) intel;

- (NSDictionary*) attributes;						// The attributes for the title being displayed in this node
- (void) setEditing: (BOOL) editing;				// Sets whether or not this node is being edited
- (NSColor*) textBackgroundColour;					// The background colour for the text in this node
- (NSRect) headerTitleRect;							// The bounding rectangle for the editable part of the name
- (NSAttributedString*) attributedTitle;			// The editable part of the title as an attributed string
- (NSString*) freshValueForEditedTitle: (NSString*) edited;	// Given an edited title, returns the exact value that should be substituted in the source code

// Drawing the node

- (void) drawNodeInRect: (NSRect) rect				// Draws this node
			  withFrame: (NSRect) frame;

@end
