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
extern NSString* IFStyleBase;

// Basic compiler messages
extern NSString* IFStyleCompilerVersion;
extern NSString* IFStyleCompilerMessage;
extern NSString* IFStyleCompilerWarning;
extern NSString* IFStyleCompilerError;
extern NSString* IFStyleCompilerFatalError;
extern NSString* IFStyleProgress;

extern NSString* IFStyleFilename;

// Compiler statistics/dumps/etc
extern NSString* IFStyleAssembly;
extern NSString* IFStyleHexDump;
extern NSString* IFStyleStatistics;

// List of tabs
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
@interface IFCompilerController : NSObject<NSTextStorageDelegate, WebPolicyDelegate, WebFrameLoadDelegate>

/// The default styles for the error messages
+ (NSDictionary<NSAttributedStringKey, id>*) defaultStyles;

/// Destroys + recreates the compiler (ie, resets it back to its initial state)
- (void)        resetCompiler;
/// Sets a specific compiler object to use
/// Retrieves the current compiler object
@property (atomic, strong) IFCompiler *compiler;

/// Tells the compiler to start
@property (atomic, readonly) BOOL startCompiling;
/// Tells the compiler to stop
@property (atomic, readonly) BOOL abortCompiling;

/// Adds an error to the display
- (void) addErrorForFile: (NSString*) file
                  atLine: (int) line
                withType: (IFLex) type
                 message: (NSString*) message;

/// Displays the window thats displaying the compiler messages
- (void) showWindow: (id) sender;
/// The delegate object
@property (atomic, strong) IBOutlet id<IFCompilerControllerDelegate> delegate;

- (void) overrideProblemsURL: (NSURL*) problemsURL;         // No matter the exit/RTP supplied by the compiler, use this problems URL instead
- (void) showRuntimeError: (NSURL*) errorURL;               // Creates a tab for the 'runtime error' file given by errorURL (displayed by webkit)
- (void) showContentsOfFilesIn: (NSFileWrapper*) files      // Creates tabs for the files contained in the given filewrapper (which came from the given path)
					  fromPath: (NSString*) path;
- (void) clearTabViews;                                     // Gets rid of the file tabs created by the previous function

@property (atomic, readonly, copy) NSString *blorbLocation; // Where cblorb thinks the final blorb file should be copied to
@property (nonatomic, strong) NSSplitView *splitView;		// The splitter view for this object

@property (atomic, readonly) IFCompilerTabId selectedTabId;	// The tab identifier of the currently selected view
- (void) switchToViewWithTabId: (IFCompilerTabId) tabId;    // Switches to a view with the specified tab identifier
- (void) switchToSplitView;                                 // Switches to the default split view
- (void) switchToRuntimeErrorView;                          // Switches to the runtime error view
@property (atomic, readonly, copy) NSArray *viewTabs;		// Returns the tabs this controller can display
- (int) tabIdWithTabIndex: (int) tabIndex;

- (void) setProjectController: (IFProjectController*) pc;

@end

// Delegate methods
@protocol IFCompilerControllerDelegate <NSObject>
@optional

// Status updates
//- (void) compileStarted: (IFCompilerController*) sender;                  // Called when the compiler starts doing things
//- (void) compileCompletedAndSucceeded: (IFCompilerController*) sender;	// Called when the compiler has finished and reports success
//- (void) compileCompletedAndFailed: (IFCompilerController*) sender;		// Called when the compiler has finished and reports failure

// User interface notification
//- (void) errorMessagesCleared: (IFCompilerController*) sender;	// Called when the list of errors are cleared
- (void) errorMessageHighlighted: (IFCompilerController*) sender	// Called when the user selects a specific error
                          atLine: (int) line
                          inFile: (NSString*) file;
//- (void) compilerAddError: (IFCompilerController*) sender			// Called when the compiler generates a new error
//                  forFile: (NSString*) file
//                   atLine: (int) line
//                 withType: (IFLex) type
//                  message: (NSString*) message;
- (BOOL) handleURLRequest: (NSURLRequest*) request;					// First chance opportunity to redirect URL requests (used so that NI error URLs are handled)
- (void) viewSetHasUpdated: (IFCompilerController*) sender;			// Notification that the compiler controller has changed its set of views
- (void) compiler: (IFCompilerController*) sender					// Notification that the compiler has switched to the specified view
   switchedToView: (int) viewIndex;	

// Project controller
- (void) setProjectController: (IFProjectController*) pc;

@end
