//
//  IFHeaderView.h
//  Inform
//
//  Created by Andrew Hunter on 02/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFHeader.h"
#import "IFHeaderNode.h"

@class IFHeaderController;

//
// View used to allow the user to restrict the section of the source file that they are
// browsing
//
@interface IFHeaderView : NSView<NSTextViewDelegate>

@property (atomic, readonly, strong) IFHeaderNode *rootHeaderNode;			// Retrieves the root header node
@property (atomic) int displayDepth;										// Sets/retrieves the display depth for this view

- (void) setBackgroundColour: (NSColor*) colour;							// Sets the background colour for this view
- (void) setDelegate: (id) delegate;										// Sets the delegate for this view
- (void) setMessage: (NSString*) message;									// Sets the message to use in this view

@end

@interface NSObject(IFHeaderViewDelegate)

- (void) headerView: (IFHeaderView*) view									// Indicates that a header node has been clicked on
	  clickedOnNode: (IFHeaderNode*) node;
- (void) headerView: (IFHeaderView*) view									// Indicates that the controller should try to update the specified header node
 		 updateNode: (IFHeaderNode*) node
 	   withNewTitle: (NSString*) newTitle;

@end