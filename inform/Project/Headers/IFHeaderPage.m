//
//  IFHeaderPage.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 02/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import "IFHeaderPage.h"
#import "NSBundle+IFBundleExtensions.h"

// = Preferences =

static NSString* IFHeaderBackgroundColour = @"IFHeaderBackgroundColour";

@implementation IFHeaderPage

// = Initialisation =

+ (void) initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults: 
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSArray arrayWithObjects: [NSNumber numberWithFloat: 0.95], [NSNumber numberWithFloat: 0.95], [NSNumber numberWithFloat: 0.9], [NSNumber numberWithFloat: 1.0], nil], IFHeaderBackgroundColour,
	  nil]];
}

- (id) init {
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
			col = [NSColor colorWithDeviceRed: [[components objectAtIndex: 0] floatValue]
										green: [[components objectAtIndex: 1] floatValue]
										 blue: [[components objectAtIndex: 2] floatValue]
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
		[controller release];				controller = nil;
	}

	[headerView setDelegate: nil];
	
	[pageView release];						pageView = nil;
	[headerView release];					headerView = nil;
	[selectedNode release];					selectedNode = nil;
	
	[super dealloc];
}

// = KVC stuff for the page view/header view =

- (NSView*) pageView {
	return pageView;
}

- (IFHeaderView*) headerView {
	return headerView;
}

- (void) setPageView: (NSView*) newPageView {
	[pageView release]; pageView = nil;
	pageView = [newPageView retain];
}

- (void) setHeaderView: (IFHeaderView*) newHeaderView {
	if (controller && headerView) [controller removeHeaderView: headerView];
	
	[headerView release]; headerView = nil;
	headerView = [newHeaderView retain];

	if (controller && headerView) [controller addHeaderView: headerView];
}

// = Managing the controller =

- (void) setController: (IFHeaderController*) newController {
	if (controller) {
		[controller removeHeaderView: headerView];
		[controller release];
		controller = nil;
	}
	
	if (newController) {
		controller = [newController retain];
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
	[selectedNode autorelease]; selectedNode = nil;
	
	selectedNode = [node retain];
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
    int depth = 1 + [depthButton indexOfSelectedItem];
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
