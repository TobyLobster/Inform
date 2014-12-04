//
//  IFPage.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFPage.h"
#import "NSBundle+IFBundleExtensions.h"

NSString* IFSwitchToPageNotification = @"IFSwitchToPageNotification";
NSString* IFUpdatePageBarCellsNotification = @"IFUpdatePageBarCellsNotification";

@implementation IFPage

// = Initialisation =

- (id) initWithNibName: (NSString*) nib
	 projectController: (IFProjectController*) controller {
	self = [super init];
	
	if (self) {
		// Load the nib file
		[NSBundle oldLoadNibNamed: nib
                            owner: self];
		
		// Set the parent
		parent = controller;
	}
	
	return self;
}

- (void) dealloc {
	if (releaseView) [view release];
	[super dealloc];
}

- (void) setThisPane: (IFProjectPane*) newThisPane {
	thisPane = newThisPane;
}

- (void) setOtherPane: (IFProjectPane*) newOtherPane {
	otherPane = newOtherPane;
}

- (void) finished {
	parent = nil;
	otherPane = nil;
}

// = Details about this view =

- (NSString*) title {
	return @"Untitled";
}

- (NSView*) view {
	return view;
}

- (NSView*) activeView {
	return view;
}

- (void) setView: (NSView*) newView {
	if (releaseView) [view autorelease];
	view = [newView retain];
	releaseView = YES;
}

- (NSString*) identifier {
	return [[self class] description];
}

// = Page validation =

- (BOOL) shouldShowPage {
	return YES;
}

// = Page actions =

- (void) switchToPage {
	[self switchToPageWithIdentifier: [self identifier]
							fromPage: nil];
}

- (void) switchToPageWithIdentifier: (NSString*) identifier
						   fromPage: (NSString*) oldPageIdentifier {
	// Post a notification that this page wants to be the frontmost
	[[NSNotificationCenter defaultCenter] postNotificationName: IFSwitchToPageNotification
														object: self
													  userInfo: [NSDictionary dictionaryWithObjectsAndKeys: 
														  identifier, @"Identifier", 
														  oldPageIdentifier, @"OldPageIdentifier", nil]];
}

// = Dealing with the page bar =

- (NSArray*) toolbarCells {
	return [NSArray array];
}

- (void) toolbarCellsHaveUpdated {
	[[NSNotificationCenter defaultCenter] postNotificationName: IFUpdatePageBarCellsNotification
														object: self];
}

// = History =

- (void) setRecorder: (NSObject<IFHistoryRecorder>*) newRecorder {
	recorder = newRecorder;
}

- (id) history {
	IFHistoryEvent* event = nil;
	
	if (recorder) {
		event = [recorder historyEvent];
	}
	
	if (event) {
		[event setTarget: self];
		return [event proxy];
	}
	
	return nil;
}

- (void) setPageIsVisible: (BOOL) newIsVisible {
	pageIsVisible = newIsVisible;
}

- (BOOL) pageIsVisible {
	return pageIsVisible;
}

- (void) didSwitchToPage {
	// Do nothing
}

- (void) didSwitchAwayFromPage {
	// Called when this page is no longer active
}

- (void) willClose {
    
}

@end
