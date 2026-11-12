//
//  IFCompilerController.h
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <AppKit/AppKit.h>

#import "IFCompiler.h"
#import "IFCompilerOutputScanner.h"
#import "IFCompilerResultFiles.h"

NS_ASSUME_NONNULL_BEGIN

@class IFProjectController;
@class IFProjectPane;
@class IFInTest;

@interface IFCompilerTab : NSObject

@property (atomic, strong) NSView*         view;
@property (atomic, strong) NSString*       name;
@property (atomic)         IFCompilerTabId tabId;

@end

@protocol IFCompilerControllerDelegate;

///
/// The compiler controller handles the interface between the compiler and the UI
///
/// (In ye olden dayes, this was a window controller as well, but now young whippersnapper
/// compilers can go anywhere, so it's not any more)
///
NS_SWIFT_UI_ACTOR
@interface IFCompilerController : NSObject<NSTextStorageDelegate, NSSplitViewDelegate>

/// The default styles for the error messages
+ (NSDictionary<NSAttributedStringKey, id>*) defaultStyles;

/// Sets a specific compiler object to use
/// Retrieves the current compiler object
@property (atomic, strong) IFCompiler *compiler;
/// The intest whose output is shown in the console; nil until it's set
@property (atomic, strong, nullable) IFInTest *inTest;

/// Adds an error to the display
- (void) addErrorForFile: (NSString*) file
                  atLine: (int) line
                withType: (IFLex) type
                 message: (NSString*) message;

/// The delegate object
@property (atomic, weak, nullable) IBOutlet id<IFCompilerControllerDelegate> delegate;

/// No matter the exit/RTP supplied by the compiler, use this problems URL instead
- (void) overrideProblemsURL: (NSURL*) problemsURL;
/// Creates a tab for the 'runtime error' file given by errorURL (displayed by webkit)
- (void) showRuntimeError: (NSURL*) errorURL;
/// Creates tabs for the files contained in the given filewrapper (which came from the given path)
- (void) showContentsOfFilesIn: (NSFileWrapper*) files
					  fromPath: (NSString*) path;
/// Gets rid of the file tabs created by the previous function
- (void) clearTabViewsExcept: (IFCompilerTabId) exceptTabId;

/// Where cblorb thinks the final blorb file should be copied to (nil if it hasn't said)
@property (atomic, readonly, copy, nullable) NSString *blorbLocation;
/// The splitter view for this object
@property (nonatomic, strong) NSSplitView *splitView;

/// The tab identifier of the currently selected view
@property (atomic, readonly) IFCompilerTabId selectedTabId;
@property (atomic, readonly, nullable) WKWebView* currentWebView;

/// Add a tab for showing results
- (IFCompilerTabId) makeTabForFile: (NSString*) file;
/// Switches to a view with the specified tab identifier
- (void) switchToViewWithTabId: (IFCompilerTabId) tabId;
/// Switches to the default split view
- (void) switchToSplitView;
/// Clears the console view of text
- (void) clearConsole: (nullable NSNotification*) not;
/// Returns the tabs this controller can display
@property (atomic, readonly, copy) NSArray<IFCompilerTab*> *viewTabs;

- (int) tabIdWithTabIndex: (int) tabIndex;

- (void) setProjectController: (IFProjectController*) pc withPane: (IFProjectPane*) pane;

@end

// Delegate methods
NS_SWIFT_UI_ACTOR
@protocol IFCompilerControllerDelegate <NSObject, WKNavigationDelegate>
@optional

// User interface notification
/// Called when the user selects a specific error
- (void) errorMessageHighlighted: (IFCompilerController*) sender
                          atLine: (int) line
                          inFile: (NSString*) file;

/// Notification that the compiler controller has changed its set of views
- (void) viewSetHasUpdated: (IFCompilerController*) sender;
/// Notification that the compiler has switched to the specified view
- (void) compiler: (IFCompilerController*) sender
   switchedToView: (int) viewIndex;	

@end

NS_ASSUME_NONNULL_END
