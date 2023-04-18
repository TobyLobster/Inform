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
#import "IFPreferences.h"

#pragma mark Preferences

@implementation IFHeaderPage {
    NSView* pageView;
    /// The scroll view
    IBOutlet NSScrollView* scrollView;
    
    IFHeaderView* headerView;
    IBOutlet NSPopUpButton* depthButton;

    /// The highlight range to use
    NSRange highlightLines;
    /// The currently selected header node
    IFHeaderNode* selectedNode;
}

#pragma mark - Initialisation

+ (void) initialize {
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		// Load the nib file
		[NSBundle oldLoadNibNamed: @"Headers"
                            owner: self];
		
		[headerView setDelegate: self];
		
        // Notification
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(preferencesChanged:)
                                                     name: IFPreferencesEditingDidChangeNotification
                                                   object: [IFPreferences sharedPreferences]];

        [self setColours];

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

- (void) setColours {
    [scrollView setBackgroundColor: [[IFPreferences sharedPreferences] getExtensionPaper].colour];
    [scrollView setNeedsDisplay:YES];
    [headerView setColours: [[IFPreferences sharedPreferences] getExtensionPaper].colour];
    [headerView setNeedsDisplay:YES];
}

- (void) preferencesChanged: (NSNotification*) not {
    [self setColours];
}

#pragma mark - KVC stuff for the page view/header view

@synthesize pageView;
@synthesize headerView;

- (void) setHeaderView: (IFHeaderView*) newHeaderView {
	if (controller && headerView) [controller removeHeaderView: headerView];
	
	headerView = newHeaderView;

	if (controller && headerView) [controller addHeaderView: headerView];
}

#pragma mark - Managing the controller

@synthesize controller;
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

@synthesize delegate;

#pragma mark - Controller delegate messages (relayed via the view)

- (void) refreshHeaders: (IFHeaderController*) control {
	if (highlightLines.location != NSNotFound) {
		[self highlightNodeWithLines: highlightLines];
	}
	
	if ([delegate respondsToSelector: @selector(refreshHeaders:)]) {
		[delegate refreshHeaders: control];
	}
}

#pragma mark - Choosing objects

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

#pragma mark - User actions =

- (IBAction) updateDepthPopup: (id) sender {
    int depth = 1 + (int) [depthButton indexOfSelectedItem];
	[headerView setDisplayDepth: depth];
	
	if (highlightLines.location != NSNotFound) {
		[self highlightNodeWithLines: highlightLines];
	}
}

#pragma mark - Header view delegate methods

- (void) headerView: (IFHeaderView*) view
	  clickedOnNode: (IFHeaderNode*) node {
	if ([delegate respondsToSelector: @selector(headerPage:limitToHeader:)]) {
		[delegate headerPage: self
			   limitToHeader: [node header]];
	}
}

- (void) headerView: (IFHeaderView*) view
 		 updateNode: (IFHeaderNode*) node
 	   withNewTitle: (NSString*) newTitle {
	if ([delegate respondsToSelector: @selector(headerView:updateNode:withNewTitle:)]) {
		[delegate headerView: view
				  updateNode: node
				withNewTitle: newTitle];
	}
}


@end
