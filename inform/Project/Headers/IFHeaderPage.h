//
//  IFHeaderPage.h
//  Inform
//
//  Created by Andrew Hunter on 02/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFHeaderView.h"

///
/// Controller object that manages the headers page
///
@interface IFHeaderPage : NSObject

// The controller and view

@property (atomic, readonly, strong) NSView *pageView;										// The view that should be used to display the headers being managed by this class
@property (atomic, readonly, strong) IFHeaderView *headerView;                               // Header view
- (void) setController: (IFHeaderController*) controller;	// Specifies the header controller that should be used to manage updates to this page
- (void) setDelegate: (id) delegate;						// Updates the delegate

// Choosing objects

- (void) selectNode: (IFHeaderNode*) node;					// Marks the specified node as being selected
- (void) highlightNodeWithLines: (NSRange) lines;			// Sets the node with the specified lines as selected

// UI actions

- (IBAction) updateDepthPopup: (id) sender;				// Message sent when the depth popup is changed

@end

@interface NSObject(IFHeaderPageDelegate)

- (void) headerPage: (IFHeaderPage*) page
	  limitToHeader: (IFHeader*) header;

@end
