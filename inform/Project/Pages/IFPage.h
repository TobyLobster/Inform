//
//  IFPage.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFProject.h"
#import "IFProjectController.h"

// Page notifications

// Notification sent by a page when it wishes to become frontmost
extern NSString* IFSwitchToPageNotification;

// Notification sent when a page wants to cause an invokation on the 'opposite' pane
extern NSString* IFOtherPaneInvokationNotification;

// Notification that the items on the toolbar for a page have changed
extern NSString* IFUpdatePageBarCellsNotification;

//#define LOG_HISTORY
#ifdef LOG_HISTORY
#define LogHistory(format, ... ) { NSLog(format, ##__VA_ARGS__); }
#else
#define LogHistory(format, ... )
#endif

//
// Controller class that represents a page in a project pane
//
@protocol IFProjectPane;
@protocol IFHistoryRecorder;
@interface IFPage : NSObject {
	IFProjectController* parent;			// The project controller that 'owns' this page (not retained)
	IFProjectPane* thisPane;		// The pane that contains this page (or nil, not retained)
	IFProjectPane* otherPane;		// The pane that is opposite to this one (or nil, not retained)
	NSObject<IFHistoryRecorder>* recorder;	// Object used for recording any history events for this object
	
	BOOL pageIsVisible;						// YES if this page is currently displayed
	BOOL releaseView;						// YES if the view has been set using setView: and should be released
	IBOutlet NSView* view;					// The view to display for this page
    NSArray *topLevelObjects;               // All top level objects for the nib loaded (so they can be released)
}

// Initialising
- (id) initWithNibName: (NSString*) nib		// Designated initialiser
	 projectController: (IFProjectController*) controller;
- (void) setRecorder: (NSObject<IFHistoryRecorder>*) recorder;	// Sets the history recorder for this item [NOT RETAINED]
- (void) setThisPane: (IFProjectPane*) thisPane;		// Sets the pane that this page is contained within
- (void) setOtherPane: (IFProjectPane*) otherPane;	// Sets the pane to be considered 'opposite' to this one
- (void) finished;							// Called when the owning object has finished with this object

// Page actions
- (void) setPageIsVisible: (BOOL) newIsVisible;	// Called by whatever is managing this page to set it to visible or not
- (BOOL) pageIsVisible;						// YES if this page is currently visible
- (void) switchToPage;						// Request that the UI switches to displaying this page
- (void) switchToPageWithIdentifier: (NSString*) identifier
						   fromPage: (NSString*) oldIdentifier;	// Request that the UI switches to displaying a specific page
- (void) didSwitchToPage;					// Called when this page becomes active
- (void) didSwitchAwayFromPage;				// Called when this page is no longer active

- (id) history;								// Returns a proxy object that can be used to record history actions

// Page properties
- (NSString*) title;						// The name of the tab this page appears under
- (NSString*) identifier;					// A unique identifier for this page
- (NSView*) view;							// The view that should be used to display this page
- (NSView*) activeView;						// The view that is considered to have focus for this page
- (void) setView: (NSView*) view;	// Sets the view to use

// Page validation
- (BOOL) shouldShowPage;					// YES if this page is valid to be shown

// Dealing with the page bar
- (NSArray*) toolbarCells;					// The cells to put on the page bar for this item
- (void) toolbarCellsHaveUpdated;			// Call to cause the set of cells being displayed in the toolbar to be updated

- (void) willClose;

@end

#import "IFProjectPane.h"
