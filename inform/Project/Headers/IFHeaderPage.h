//
//  IFHeaderPage.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 02/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFHeaderView.h"

///
/// Controller object that manages the headers page
///
@interface IFHeaderPage : NSObject {
	IBOutlet NSView* pageView;								// The main header page view
	IBOutlet NSScrollView* scrollView;						// The scroll view
	IBOutlet IFHeaderView* headerView;						// The header view that this object is managing
    IBOutlet NSPopUpButton* depthButton;
	
	IFHeaderController* controller;							// The header controller that this page is using
	
	NSRange highlightLines;									// The highlight range to use
	IFHeaderNode* selectedNode;								// The currently selected header node
	
	id delegate;											// The delegate for this page object
}

// The controller and view

- (NSView*) pageView;										// The view that should be used to display the headers being managed by this class
- (IFHeaderView*) headerView;                               // Header view
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
