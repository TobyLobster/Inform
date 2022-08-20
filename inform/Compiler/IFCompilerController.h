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
#import "IFError.h"

@class IFProjectController;

// Possible styles (stored in the styles dictionary)
extern NSString* const IFStyleBase;

// Basic compiler messages
extern NSString* const IFStyleCompilerVersion;
extern NSString* const IFStyleCompilerMessage;
extern NSString* const IFStyleCompilerWarning;
extern NSString* const IFStyleCompilerError;
extern NSString* const IFStyleCompilerFatalError;
extern NSString* const IFStyleProgress;

extern NSString* const IFStyleFilename;

// Compiler statistics/dumps/etc
extern NSString* const IFStyleAssembly;
extern NSString* const IFStyleHexDump;
extern NSString* const IFStyleStatistics;

/// List of tabs
typedef NS_ENUM(unsigned int, IFCompilerTabId) {
    IFTabReport,
    IFTabConsole,
    IFTabDebugging,
    IFTabInform6,
    IFTabRuntime,
    IFTabInvalid,
};

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
@interface IFCompilerController : NSObject<NSTextStorageDelegate, NSSplitViewDelegate, WebPolicyDelegate, WebFrameLoadDelegate>

/// The default styles for the error messages
+ (NSDictionary<NSAttributedStringKey, id>*) defaultStyles;

/// Destroys + recreates the compiler (ie, resets it back to its initial state)
- (void)        resetCompiler;
/// Sets a specific compiler object to use
/// Retrieves the current compiler object
@property (atomic, strong) IFCompiler *compiler;

/// Tells the compiler to start
- (BOOL) startCompiling;
/// Tells the compiler to stop
- (BOOL) abortCompiling;

/// Adds an error to the display
- (void) addErrorForFile: (NSString*) file
                  atLine: (int) line
                withType: (IFLex) type
                 message: (NSString*) message;

/// Displays the window thats displaying the compiler messages
- (void) showWindow: (id) sender;
/// The delegate object
@property (atomic, weak) IBOutlet id<IFCompilerControllerDelegate> delegate;

/// No matter the exit/RTP supplied by the compiler, use this problems URL instead
- (void) overrideProblemsURL: (NSURL*) problemsURL;
/// Creates a tab for the 'runtime error' file given by errorURL (displayed by webkit)
- (void) showRuntimeError: (NSURL*) errorURL;
/// Creates tabs for the files contained in the given filewrapper (which came from the given path)
- (void) showContentsOfFilesIn: (NSFileWrapper*) files
					  fromPath: (NSString*) path;
/// Gets rid of the file tabs created by the previous function
- (void) clearTabViews;

/// Where cblorb thinks the final blorb file should be copied to
@property (atomic, readonly, copy) NSString *blorbLocation;
/// The splitter view for this object
@property (nonatomic, strong) NSSplitView *splitView;

/// The tab identifier of the currently selected view
@property (atomic, readonly) IFCompilerTabId selectedTabId;
/// Switches to a view with the specified tab identifier
- (void) switchToViewWithTabId: (IFCompilerTabId) tabId;
/// Switches to the default split view
- (void) switchToSplitView;
/// Switches to the runtime error view
- (void) switchToRuntimeErrorView;
/// Returns the tabs this controller can display
@property (atomic, readonly, copy) NSArray *viewTabs;

- (int) tabIdWithTabIndex: (int) tabIndex;

- (void) setProjectController: (IFProjectController*) pc;

@end

// Delegate methods
@protocol IFCompilerControllerDelegate <NSObject>
@optional

// Status updates
//- (void) compileStarted: (IFCompilerController*) sender;                  // Called when the compiler starts doing things
//- (void) compileCompletedAndSucceeded: (IFCompilerController*) sender;	// Called when the compiler has finished and reports success
/// Called when the compiler has finished and reports failure
- (void) compileCompletedAndFailed: (IFCompilerController*) sender;

// User interface notification
/// Called when the list of errors are cleared
- (void) errorMessagesCleared: (IFCompilerController*) sender;

/// Called when the user selects a specific error
- (void) errorMessageHighlighted: (IFCompilerController*) sender
                          atLine: (int) line
                          inFile: (NSString*) file;
/// Called when the compiler generates a new error
- (void) compilerAddError: (IFCompilerController*) sender
                  forFile: (NSString*) file
                   atLine: (int) line
                 withType: (IFLex) type
                  message: (NSString*) message;

/// First chance opportunity to redirect URL requests (used so that NI error URLs are handled)
- (BOOL) handleURLRequest: (NSURLRequest*) request;
/// Notification that the compiler controller has changed its set of views
- (void) viewSetHasUpdated: (IFCompilerController*) sender;
/// Notification that the compiler has switched to the specified view
- (void) compiler: (IFCompilerController*) sender
   switchedToView: (int) viewIndex;	

// Project controller
- (void) setProjectController: (IFProjectController*) pc;

@end
