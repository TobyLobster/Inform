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

NSString* const IFSwitchToPageNotification = @"IFSwitchToPageNotification";
NSString* const IFUpdatePageBarCellsNotification = @"IFUpdatePageBarCellsNotification";

@implementation IFPage {
    /// Object used for recording any history events for this object
    __weak id<IFHistoryRecorder> recorder;

    /// \c YES if this page is currently displayed
    BOOL pageIsVisible;
    /// YES if the view has been set using setView: and should be released
    BOOL releaseView;
    /// All top level objects for the nib loaded (so they can be released)
    NSArray *topLevelObjects;
}

@synthesize view;

#pragma mark - Initialisation

- (instancetype) initWithNibName: (NSString*) nib
	 projectController: (IFProjectController*) controller {
	self = [super init];
	
	if (self) {
		// Load the nib file
		[NSBundle customLoadNib: nib
                          owner: self];
		
		// Set the parent
		_parent = controller;
	}
	
	return self;
}

- (void) finished {
	_parent = nil;
	_otherPane = nil;
}

#pragma mark - Details about this view

- (NSString*) title {
	return @"Untitled";
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

#pragma mark - Page validation

- (BOOL) shouldShowPage {
	return YES;
}

#pragma mark - Page actions

- (void) switchToPage {
	[self switchToPageWithIdentifier: self.identifier
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

#pragma mark - Dealing with the page bar

- (NSArray*) toolbarCells {
	return @[];
}

- (void) toolbarCellsHaveUpdated {
	[[NSNotificationCenter defaultCenter] postNotificationName: IFUpdatePageBarCellsNotification
														object: self];
}

#pragma mark - History

@synthesize recorder;

- (id) history {
	IFHistoryEvent* event = nil;
	
	if (recorder) {
		event = recorder.historyEvent;
	}
	
	if (event) {
		event.target = self;
		return event.proxy;
	}
	
	return nil;
}

@synthesize pageIsVisible;

- (void) didSwitchToPage {
	// Do nothing
}

- (void) didSwitchAwayFromPage {
	// Called when this page is no longer active
}

- (void) willClose {
    
}

@end
