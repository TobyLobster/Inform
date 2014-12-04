//
//  IFProjectPane.h
//  Inform
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "IFCompilerController.h"

#import <ZoomView/ZoomView.h>
#import <ZoomView/ZoomSkeinView.h>

#import <GlkView/GlkView.h>

#import "IFSettingsView.h"
#import "IFSettingsController.h"
#import "IFTranscriptView.h"

#import "IFSyntaxTypes.h"
#import "IFProgress.h"

#import "IFPageBarView.h"
#import "IFPageBarCell.h"
#import "IFHistoryEvent.h"

enum IFProjectPaneType {
    IFSourcePane = 1,
    IFErrorPane = 2,
    IFGamePane = 3,
    IFDocumentationPane = 4,
	IFIndexPane = 5,
	IFSkeinPane = 6,
	IFTranscriptPane = 8,
    IFExtensionsPane = 9,
	
	IFUnknownPane = 256
};

@class IFProjectController;
@class IFPage;
@class IFSourcePage;
@class IFErrorsPage;
@class IFIndexPage;
@class IFSkeinPage;
@class IFTranscriptPage;
@class IFGamePage;
@class IFDocumentationPage;
@class IFExtensionsPage;
@class IFSettingsPage;

//
// Protocol that can be implemented by other objects that wish to act like the 'other' panel when actions
// can span both panels
//
@protocol IFProjectPane<NSTabViewDelegate>

// Selecting the view
- (void) selectViewOfType: (enum IFProjectPaneType) pane;				// Changes the view displayed in this pane to the specified setting

// The source page
- (IFSourcePage*) sourcePage;									// The page representing the source page

@end

@protocol IFHistoryRecorder

- (IFHistoryEvent*) historyEvent;								// Retrieves a history event that can have new events recorded via the proxy

@end

//
// Controller class dealing with one side of the project window
//
@interface IFProjectPane : NSObject<IFProjectPane, IFHistoryRecorder> {
    // Outlets
    IBOutlet NSView* paneView;							// The main pane view
    IBOutlet NSTabView* tabView;						// The tab view
	
	// The page bar
	IBOutlet IFPageBarView* pageBar;					// The page toolbar
	
	IFPageBarCell* forwardCell;							// The 'forward' button
	IFPageBarCell* backCell;							// The 'backwards' button
	
	// History
	NSMutableArray* history;							// The history actions for this object
	IFHistoryEvent* lastEvent;							// The last history event created
	int historyPos;										// The position that we are in the history
	BOOL replaying;										// If true, then new history items are not created
	
	// The pages
	NSMutableArray* pages;								// Pages being managed by this control
	
	// The pages
	IFSourcePage* sourcePage;							// The source page
	IFErrorsPage* errorsPage;							// The errors page
	IFIndexPage* indexPage;								// The index page
	IFSkeinPage* skeinPage;								// The skein page
	IFTranscriptPage* transcriptPage;					// The transcript page
	IFGamePage* gamePage;								// The game page
	IFDocumentationPage* documentationPage;				// The documentation page
    IFExtensionsPage* extensionsPage;                   // The extensions page
	IFSettingsPage* settingsPage;						// The settings page
	
    // Other variables
    BOOL awake;											// YES if we've loaded from the nib and initialised properly
    IFProjectController* parent;						// The 'parent' project controller (not retained)
}

+ (IFProjectPane*) standardPane;								// Create/load a project pane
+ (NSDictionary*) attributeForStyle: (IFSyntaxStyle) style;		// Retrieve the attributes to use for a certain syntax highlighting style

// Our controller
- (void) setController: (IFProjectController*) parent;			// Sets the project controller (once the nib has loaded and the project controller been set, we are considered 'awake')
- (IFProjectController*) controller;                            // Gets the project controller
- (void) willClose;												// Notification from the controller that this object will be destroyed shortly

// Dealing with the contents of the NIB file
- (NSView*) paneView;											// The main pane view
- (NSView*) activeView;											// The presently displayed pane
- (void) removeFromSuperview;									// Removes the pane from its superview

- (IFCompilerController*) compilerController;					// The compiler controller associated with this view

// Dealing with pages
- (void) addPage: (IFPage*) newPage;							// Adds a new page to this control

- (void) setIsActive: (BOOL) isActive;							// Sets whether or not this pane should be the default for keyboard events

// Selecting the view
- (void) selectViewOfType: (enum IFProjectPaneType) pane;		// Changes the view displayed in this pane to the specified setting
- (enum IFProjectPaneType) currentView;							// Returns the currently displayed view (IFUnknownPane is a possibility for some views I haven't added code to check for)
- (NSTabView*) tabView;											// The tab view itself

// The source page
- (void) prepareToCompile;										// Informs this pane that it's time to prepare to compile (or save) the document
- (void) showSourceFile: (NSString*) file;						// Sets the source page to show a specific source file
- (IFSourcePage*) sourcePage;									// The page representing the source code

// The errors page
- (IFErrorsPage*) errorsPage;									// The page displaying the results from the compiler

// The index page
- (IFIndexPage*) indexPage;										// The page representing the index

// The skein page
- (IFSkeinPage*) skeinPage;										// The page representing the skein

// The transcript page
- (IFTranscriptPage*) transcriptPage;							// The page representing the transcript

// The settings page
- (IFSettingsPage*) settingsPage;								// The page representing the settings for this project

// The game page
- (IFGamePage*) gamePage;										// The page representing the running game
- (void) stopRunningGame;										// Convenience method

// The documentation page
- (IFDocumentationPage*) documentationPage;						// The page representing the documentation

// The extensions page
- (IFExtensionsPage*) extensionsPage;                           // The page representing the extensions

// Search/replace
- (void) performFindPanelAction: (id) sender;					// Called to invoke the find panel for the current pane

// History
- (IFHistoryEvent*) historyEvent;								// Gets the current history event for this run through the loop
- (void) addHistoryInvocation: (NSInvocation*) invoke;			// Adds a new invocation to the forward/backwards history
- (id) history;													// Returns a proxy for this object for a new history item

- (IBAction) goForwards: (id) sender;							// Go forwards in the history
- (IBAction) goBackwards: (id) sender;							// Go backwards in the history

// Extension updated
-(void) extensionUpdated:(NSString*) javascriptId;

@end

#import "IFProjectController.h"
#import "IFPage.h"
#import "IFSourcePage.h"
#import "IFErrorsPage.h"
#import "IFIndexPage.h"
#import "IFSkeinPage.h"
#import "IFTranscriptPage.h"
#import "IFGamePage.h"
#import "IFDocumentationPage.h"
#import "IFExtensionsPage.h"
#import "IFSettingsPage.h"
