//
//  IFPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFPage.h"
#import "NSBundle+IFBundleExtensions.h"
#import "IFProjectFile.h"
#import "IFProjectPane.h"
#import "IFHistoryEvent.h"

NSString* IFSwitchToPageNotification = @"IFSwitchToPageNotification";
NSString* IFUpdatePageBarCellsNotification = @"IFUpdatePageBarCellsNotification";

@implementation IFPage {
    IFProjectPane* thisPane;		// The pane that contains this page (or nil, not retained)
    NSObject<IFHistoryRecorder>* recorder;	// Object used for recording any history events for this object

    BOOL pageIsVisible;						// YES if this page is currently displayed
    BOOL releaseView;						// YES if the view has been set using setView: and should be released
    NSArray *topLevelObjects;               // All top level objects for the nib loaded (so they can be released)
}

@synthesize view;

// = Initialisation =

- (instancetype) initWithNibName: (NSString*) nib
	 projectController: (IFProjectController*) controller {
	self = [super init];
	
	if (self) {
		// Load the nib file
		[NSBundle oldLoadNibNamed: nib
                            owner: self];
		
		// Set the parent
		_parent = controller;
	}
	
	return self;
}


- (void) setThisPane: (IFProjectPane*) newThisPane {
	thisPane = newThisPane;
}

- (void) setOtherPane: (IFProjectPane*) newOtherPane {
	_otherPane = newOtherPane;
}

- (void) finished {
	_parent = nil;
	_otherPane = nil;
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
	view = newView;
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
    NSDictionary* userInfo;
    if( oldPageIdentifier != nil )
    {
        userInfo = @{@"Identifier": identifier,
                     @"OldPageIdentifier": oldPageIdentifier};
    }
    else
    {
        userInfo = @{@"Identifier": identifier};
    }
	// Post a notification that this page wants to be the frontmost
	[[NSNotificationCenter defaultCenter] postNotificationName: IFSwitchToPageNotification
														object: self
													  userInfo: userInfo];
}

// = Dealing with the page bar =

- (NSArray*) toolbarCells {
	return @[];
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
