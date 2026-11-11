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
#import "IFProjectPaneType.h"

NS_ASSUME_NONNULL_BEGIN

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

///
/// Protocol that can be implemented by other objects that wish to act like the 'other' panel when actions
/// can span both panels
///
@protocol IFProjectPane<NSTabViewDelegate>

/// Changes the view displayed in this pane to the specified setting
- (void) selectViewOfType: (IFProjectPaneType) pane;
/// The page representing the source page
@property (NS_NONATOMIC_IOSONLY, readonly, strong) IFSourcePage *sourcePage;

@end

@protocol IFHistoryRecorder <NSObject>

/// Retrieves a history event that can have new events recorded via the proxy (nil while replaying history)
@property (NS_NONATOMIC_IOSONLY, readonly, strong, nullable) IFHistoryEvent *historyEvent;

@end

//
// Controller class dealing with one side of the project window
//
NS_SWIFT_UI_ACTOR
@interface IFProjectPane : NSObject<IFProjectPane, IFHistoryRecorder>

// Class methods
/// Create/load a project pane
+ (IFProjectPane*) standardPane;
/// Retrieve the attributes to use for a certain syntax highlighting style
+ (NSDictionary<NSAttributedStringKey, id>*) attributeForStyle: (IFSyntaxStyle) style;

// Sets the project controller (once the nib has loaded and the project controller been set, we are considered 'awake')
- (void) setController: (IFProjectController*) p
             viewIndex: (NSInteger) viewIndex;


// Dealing with the contents of the NIB file
/// The main pane view
@property (nonatomic, readwrite, strong) IBOutlet NSView *    paneView;
/// The presently displayed pane
@property (atomic, readonly, strong, nullable) NSView *       activeView;
/// The compiler controller associated with this view
@property (atomic, readonly, strong) IFCompilerController *   compilerController;
/// Returns the currently displayed view (\c IFUnknownPane for the settings, which have no type of view of their own)
@property (atomic, readonly) IFProjectPaneType                currentView;
/// The tab view itself
@property (atomic, readwrite, strong) IBOutlet NSTabView *    tabView;

// Pages
/// The page representing the source code
@property (atomic, readonly, strong) IFSourcePage *           sourcePage;
/// The page displaying the results from the compiler
@property (atomic, readonly, strong) IFErrorsPage *           errorsPage;
/// The page representing the index
@property (atomic, readonly, strong) IFIndexPage *            indexPage;
/// The page representing the skein
@property (atomic, readonly, strong) IFSkeinPage *            skeinPage;
/// The page representing the settings for this project
@property (atomic, readonly, strong) IFSettingsPage *         settingsPage;
/// The page representing the running game; only the second pane has one
@property (atomic, readonly, strong, nullable) IFGamePage *   gamePage;
/// The page representing the documentation
@property (atomic, readonly, strong) IFDocumentationPage *    documentationPage;
/// The page representing the extensions
@property (atomic, readonly, strong) IFExtensionsPage *       extensionsPage;


/// Notification from the controller that this object will be destroyed shortly
- (void) willClose;
/// Removes the pane from its superview
- (void) removeFromSuperview;

// Dealing with pages
/// Adds a new page to this control
- (void) addPage: (IFPage*) newPage;

/// Sets whether or not this pane should be the default for keyboard events
- (void) setIsActive: (BOOL) isActive;

// Selecting the view
/// Changes the view displayed in this pane to the specified setting
- (void) selectViewOfType: (IFProjectPaneType) pane;

// The source page
/// Informs this pane that it's time to prepare to save the document
- (void) prepareToSave;

// The game page
/// Convenience method
- (void) stopRunningGame;

// History
/// Gets the current history event for this run through the loop (nil while replaying history)
@property (atomic, readonly, strong, nullable) IFHistoryEvent * historyEvent;
/// Returns a proxy for this object for a new history item (nil while replaying history)
@property (atomic, readonly, strong, nullable) id               history;
/// Shows the tab given, as the history records doing
- (void) selectTabViewItem: (NSTabViewItem*) item;
/// Makes the page's active view the window's first responder, as the history records doing
- (void) activatePage: (nullable IFPage*) page;
/// Go forwards in the history
- (IBAction) goForwards: (nullable id) sender;
/// Go backwards in the history
- (IBAction) goBackwards: (nullable id) sender;

// Extension updated
- (void) extensionUpdated:(nullable NSString*) javascriptId;

@end

NS_ASSUME_NONNULL_END
