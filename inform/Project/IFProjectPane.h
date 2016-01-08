//
//  IFProjectPane.h
//  Inform
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "IFSyntaxTypes.h"

@class IFProgress;
@class IFPageBarView;
@class IFPageBarCell;
@class IFHistoryEvent;
@class IFProjectController;
@class IFPage;
@class IFSourcePage;
@class IFErrorsPage;
@class IFIndexPage;
@class IFSkeinPage;
@class IFGamePage;
@class IFDocumentationPage;
@class IFExtensionsPage;
@class IFSettingsPage;
@class IFCompilerController;

typedef enum IFProjectPaneType {
    IFSourcePane        = 1,
    IFErrorPane         = 2,
    IFGamePane          = 3,
    IFDocumentationPane = 4,
	IFIndexPane         = 5,
	IFSkeinPane         = 6,
    IFExtensionsPane    = 9,

	IFUnknownPane       = 256
} IFProjectPaneType;

//
// Protocol that can be implemented by other objects that wish to act like the 'other' panel when actions
// can span both panels
//
@protocol IFProjectPane<NSTabViewDelegate>

- (void) selectViewOfType: (IFProjectPaneType) pane;            // Changes the view displayed in this pane to the specified setting
- (IFSourcePage*) sourcePage;                                   // The page representing the source page

@end

@protocol IFHistoryRecorder

- (IFHistoryEvent*) historyEvent;                               // Retrieves a history event that can have new events recorded via the proxy

@end

//
// Controller class dealing with one side of the project window
//
@interface IFProjectPane : NSObject<IFProjectPane, IFHistoryRecorder>

// Class methods
+ (IFProjectPane*) standardPane;								// Create/load a project pane
+ (NSDictionary*) attributeForStyle: (IFSyntaxStyle) style;		// Retrieve the attributes to use for a certain syntax highlighting style

// Sets the project controller (once the nib has loaded and the project controller been set, we are considered 'awake')
- (IFProjectController*) controller;
- (void) setController: (IFProjectController*) p
             viewIndex: (int) viewIndex;


// Dealing with the contents of the NIB file
@property (atomic, readonly, strong) NSView *                 paneView;			// The main pane view
@property (atomic, readonly, strong) NSView *                 activeView;			// The presently displayed pane
@property (atomic, readonly, strong) IFCompilerController *   compilerController;	// The compiler controller associated with this view
@property (atomic, readonly) IFProjectPaneType                currentView;        // Returns the currently displayed view (IFUnknownPane is a possibility for some views I haven't added code to check for)
@property (atomic, readonly, strong) NSTabView *              tabView;            // The tab view itself

// Pages
@property (atomic, readonly, strong) IFSourcePage *           sourcePage;         // The page representing the source code
@property (atomic, readonly, strong) IFErrorsPage *           errorsPage;			// The page displaying the results from the compiler
@property (atomic, readonly, strong) IFIndexPage *            indexPage;			// The page representing the index
@property (atomic, readonly, strong) IFSkeinPage *            skeinPage;			// The page representing the skein
@property (atomic, readonly, strong) IFSettingsPage *         settingsPage;		// The page representing the settings for this project
@property (atomic, readonly, strong) IFGamePage *             gamePage;			// The page representing the running game
@property (atomic, readonly, strong) IFDocumentationPage *    documentationPage;	// The page representing the documentation
@property (atomic, readonly, strong) IFExtensionsPage *       extensionsPage;     // The page representing the extensions


- (void) willClose;												// Notification from the controller that this object will be destroyed shortly
- (void) removeFromSuperview;									// Removes the pane from its superview

// Dealing with pages
- (void) addPage: (IFPage*) newPage;							// Adds a new page to this control

- (void) setIsActive: (BOOL) isActive;							// Sets whether or not this pane should be the default for keyboard events

// Selecting the view
- (void) selectViewOfType: (IFProjectPaneType) pane;            // Changes the view displayed in this pane to the specified setting

// The source page
- (void) prepareToSave;                                         // Informs this pane that it's time to prepare to save the document
- (void) showSourceFile: (NSString*) file;                      // Sets the source page to show a specific source file

// The game page
- (void) stopRunningGame;                                       // Convenience method

// Search/replace
- (void) performFindPanelAction: (id) sender;                   // Called to invoke the find panel for the current pane

// History
@property (atomic, readonly, strong) IFHistoryEvent * historyEvent;	// Gets the current history event for this run through the loop
@property (atomic, readonly, strong) id               history;		// Returns a proxy for this object for a new history item
- (void) addHistoryInvocation: (NSInvocation*) invoke;                              // Adds a new invocation to the forward/backwards history
- (IBAction) goForwards: (id) sender;                                               // Go forwards in the history
- (IBAction) goBackwards: (id) sender;                                              // Go backwards in the history

// Extension updated
- (void) extensionUpdated:(NSString*) javascriptId;

@end
