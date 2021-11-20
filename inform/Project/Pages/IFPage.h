//
//  IFPage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IFProject;
@class IFProjectController;
@class IFProjectPane;

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
@interface IFPage : NSObject

/// The project controller that 'owns' this page
@property (atomic, readonly, weak) IFProjectController* parent;
/// The pane that is opposite to this one (or nil)
@property (atomic, readonly, weak) IFProjectPane* otherPane;
/// The view to display for this page
@property (nonatomic, readonly, strong) IBOutlet NSView* view;


// Initialising
- (instancetype) initWithNibName: (NSString*) nib
               projectController: (IFProjectController*) controller;
/// The history recorder for this item [NOT RETAINED]
@property (atomic, readwrite, weak) id<IFHistoryRecorder> recorder;
/// Sets the pane that this page is contained within
- (void) setThisPane: (IFProjectPane*) thisPane;
/// Sets the pane to be considered 'opposite' to this one
- (void) setOtherPane: (IFProjectPane*) otherPane;
/// Called when the owning object has finished with this object
- (void) finished;

// Page actions	- Called by whatever is managing this page to set it to visible or not
/// YES if this page is currently visible
@property (atomic) BOOL pageIsVisible;
/// Request that the UI switches to displaying this page
- (void) switchToPage;
/// Request that the UI switches to displaying a specific page
- (void) switchToPageWithIdentifier: (NSString*) identifier
						   fromPage: (NSString*) oldIdentifier;
/// Called when this page becomes active
- (void) didSwitchToPage;
/// Called when this page is no longer active
- (void) didSwitchAwayFromPage;

/// Returns a proxy object that can be used to record history actions
@property (atomic, readonly, strong) id history;

// Page properties
/// The name of the tab this page appears under
@property (atomic, readonly, copy) NSString *title;
/// A unique identifier for this page
@property (atomic, readonly, copy) NSString *identifier;
/// The view that is considered to have focus for this page    // Sets the view to use
@property (atomic, readonly, strong) NSView *activeView;

// Page validation
/// YES if this page is valid to be shown
@property (atomic, readonly) BOOL shouldShowPage;

// Dealing with the page bar
/// The cells to put on the page bar for this item
@property (atomic, readonly, copy) NSArray *toolbarCells;
/// Call to cause the set of cells being displayed in the toolbar to be updated
- (void) toolbarCellsHaveUpdated;

- (void) willClose;

@end
