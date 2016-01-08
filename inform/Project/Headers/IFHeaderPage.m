//
//  IFHeaderPage.m
//  Inform
//
//  Created by Andrew Hunter on 02/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import "IFHeaderPage.h"
#import "NSBundle+IFBundleExtensions.h"
#import "IFHeaderController.h"

// = Preferences =

static NSString* IFHeaderBackgroundColour = @"IFHeaderBackgroundColour";

@implementation IFHeaderPage {
    IBOutlet NSView* pageView;								// The main header page view
    IBOutlet NSScrollView* scrollView;						// The scroll view
    IBOutlet IFHeaderView* headerView;						// The header view that this object is managing
    IBOutlet NSPopUpButton* depthButton;

    IFHeaderController* controller;							// The header controller that this page is using

    NSRange highlightLines;									// The highlight range to use
    IFHeaderNode* selectedNode;								// The currently selected header node

    id delegate;											// The delegate for this page object
}

// = Initialisation =

+ (void) initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults: 
	 @{IFHeaderBackgroundColour: @[@0.95f, @0.95f, @0.9f, @1.0f]}];
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		// Load the nib file
		[NSBundle oldLoadNibNamed: @"Headers"
                            owner: self];
		
		[headerView setDelegate: self];
		
		// Set the colours
		NSArray* components = [[NSUserDefaults standardUserDefaults] objectForKey: IFHeaderBackgroundColour];
	    NSColor* col = [NSColor whiteColor];
		
		if ([components isKindOfClass: [NSArray class]] && [components count] >= 3) {
			col = [NSColor colorWithDeviceRed: [components[0] floatValue]
										green: [components[1] floatValue]
										 blue: [components[2] floatValue]
										alpha: 1.0];
		}
		
		[scrollView setBackgroundColor: col];
		[headerView setBackgroundColour: col];
		
		// Set the view depth
        if( [depthButton numberOfItems] > 0 ) {
            [depthButton selectItemAtIndex:[depthButton numberOfItems] - 1];
        }
		[self updateDepthPopup: self];
	}
	
	return self;
}

- (void) dealloc {
	if (controller) {
		if (headerView) [controller removeHeaderView: headerView];
	}
	[headerView setDelegate: nil];
}

// = KVC stuff for the page view/header view =

- (NSView*) pageView {
	return pageView;
}

- (IFHeaderView*) headerView {
	return headerView;
}

- (void) setPageView: (NSView*) newPageView {
	pageView = newPageView;
}

- (void) setHeaderView: (IFHeaderView*) newHeaderView {
	if (controller && headerView) [controller removeHeaderView: headerView];
	
	headerView = newHeaderView;

	if (controller && headerView) [controller addHeaderView: headerView];
}

// = Managing the controller =

- (void) setController: (IFHeaderController*) newController {
	if (controller) {
		[controller removeHeaderView: headerView];
		controller = nil;
	}
	
	if (newController) {
		controller = newController;
		if (headerView) [newController addHeaderView: headerView];
	}
}

- (void) setDelegate: (id) newDelegate {
	delegate = newDelegate;
}

// = Controller delegate messages (relayed via the view) =

- (void) refreshHeaders: (IFHeaderController*) control {
	if (highlightLines.location != NSNotFound) {
		[self highlightNodeWithLines: highlightLines];
	}
	
	if (delegate && [delegate respondsToSelector: @selector(refreshHeaders:)]) {
		[delegate refreshHeaders: control];
	}
}

// = Choosing objects =

- (void) selectNode: (IFHeaderNode*) node {
	highlightLines.location = NSNotFound;
	if (node == selectedNode) return;
	
	[selectedNode setSelectionStyle: IFHeaderNodeUnselected];

    selectedNode = node;
	[selectedNode setSelectionStyle: IFHeaderNodeSelected];
	[headerView setNeedsDisplay: YES];
}

- (void) highlightNodeWithLines: (NSRange) lines {
	IFHeaderNode* lineNode = [[headerView rootHeaderNode] nodeWithLines: lines
															  intelFile: [controller intelFile]];
	if (lineNode == [headerView rootHeaderNode]) lineNode = nil;
	
	[self selectNode: lineNode];
	highlightLines = lines;
}

// = User actions =

- (IBAction) updateDepthPopup: (id) sender {
    int depth = 1 + (int) [depthButton indexOfSelectedItem];
	[headerView setDisplayDepth: depth];
	
	if (highlightLines.location != NSNotFound) {
		[self highlightNodeWithLines: highlightLines];
	}
}

// = Header view delegate methods =

- (void) headerView: (IFHeaderView*) view
	  clickedOnNode: (IFHeaderNode*) node {
	if (delegate && [delegate respondsToSelector: @selector(headerPage:limitToHeader:)]) {
		[delegate headerPage: self
			   limitToHeader: [node header]];
	}
}

- (void) headerView: (IFHeaderView*) view
 		 updateNode: (IFHeaderNode*) node
 	   withNewTitle: (NSString*) newTitle {
	if (delegate && [delegate respondsToSelector: @selector(headerView:updateNode:withNewTitle:)]) {
		[delegate headerView: view
				  updateNode: node
				withNewTitle: newTitle];
	}
}


@end
