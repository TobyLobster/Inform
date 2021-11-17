//
//  GlkView.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKVIEW_H__
#define __GLKVIEW_GLKVIEW_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import <GlkView/GlkSessionProtocol.h>
#import <GlkView/GlkWindow.h>
#import <GlkView/GlkEvent.h>
#import <GlkView/GlkPreferences.h>
#import <GlkView/GlkStyle.h>

NS_ASSUME_NONNULL_BEGIN

@protocol GlkAutomation;
@protocol GlkViewDelegate;

typedef NS_ENUM(NSInteger, GlkLogStatus) {
	/// Routine log message
	GlkLogRoutine,
	/// Informational log message
	GlkLogInformation,
	/// Custom log message (from the game, for example)
	GlkLogCustom,
	/// Warning log message
	GlkLogWarning,
	/// Error log message
	GlkLogError,
	/// Fatal error log message
	GlkLogFatalError,
};

///
/// Base class for CocoaGlk: a view object that an application can embed in order to run Glk client applications
///
@interface GlkView : NSView<GlkSession, GlkBuffer, GlkEventReceiver> {
	// Windows
	/// Maps identifiers to windows
	NSMutableDictionary<NSNumber*,GlkWindow*>* glkWindows;
	/// Most recent save panel
	NSSavePanel* lastPanel;
	/// The root window
	GlkWindow* rootWindow;
	/// The last root window
	GlkWindow* lastRootWindow;
	
	/// Used when flushing the buffer
	BOOL windowsNeedLayout;
	/// A buffer is currently flushing if \c YES
	BOOL flushing;
	
	// Styles
	/// Active preferences
	GlkPreferences* prefs;
	/// Active styles
	NSMutableDictionary<NSNumber*,NSMutableDictionary*>* styles;
	/// The active scale factor
	CGFloat scaleFactor;
	/// The border width to set for new pair windows
	int borderWidth;
	
	// Streams
	/// Maps identifiers to streams
	NSMutableDictionary<NSNumber*,id<GlkStream>>* glkStreams;

	/// The input stream
	id<GlkStream> inputStream;
	/// Maps keys to extra input streams
	NSMutableDictionary* extraStreamDictionary;
	/// Used while prompting for a file
	id<GlkFilePrompt> promptHandler;
	/// Types of files we can show in the panels
	NSArray<NSString*>* allowedFiletypes;
	
	/// \c YES if windows in this view should automatically page through more prompts
	BOOL alwaysPageOnMore;
	
	// File handling
	/// Dictionary mapping the file usage strings to the list of allowed file types
	NSMutableDictionary* extensionsForUsage;
	
	// Events
	/// The last Arrange event we received
	GlkEvent* arrangeEvent;
	/// The listener for events
	id<GlkEventListener> listener;
	/// The queue of waiting events
	NSMutableArray* events;
	
	/// The synchronisation counter
	NSInteger syncCount;
	
	// The logo
	/// Used to draw the fading logo
	NSWindow* logoWindow;
	/// The time we started fading the logo
	NSDate* fadeStart;
	/// Used to fade out the logo
	NSTimer* fadeTimer;

	NSTimeInterval waitTime;
	NSTimeInterval fadeTime;
	
	// The task
	/// \c YES if the task is running
	BOOL running;
	/// The session cookie to use with this view
	NSString* viewCookie;
	/// Only used if this is connected as a session via the \c launchClientApplication: method
	NSTask* subtask;
	
	// The delegate
	/// Can respond to certain events if it likes
	__weak id<GlkViewDelegate> delegate;
	
	// Images and graphics
	/// Source of data for images
	id<GlkImageSource> imgSrc;
	/// Dictionary of images
	NSMutableDictionary* imageDictionary;
	/// Dictionary of flipped images
	NSMutableDictionary* flippedImageDictionary;
	
	// Input history
	/// History of input lines
	NSMutableArray* inputHistory;
	/// Current history position
	NSInteger historyPosition;
	
	// Automation
	/// The automation output receivers attached to this view
	NSMutableArray<id<GlkAutomation>>* outputReceivers;
	/// The automation input receiver attached to this view
	NSMutableArray<id<GlkAutomation>>* inputReceivers;
	
	/// The automation window identifier cache
	NSMutableDictionary* windowPositionCache;
	/// The automation window position -> GlkWindow cache
	NSMutableDictionary* windowIdCache;
}

// Some shared settings
/// Image displayed while there is no root window
@property (class, readonly, retain) NSImage *defaultLogo;

// Setting up for launch
/// If cookie is non-nil, a client application must know the cookie to connect to this view. If nil, this view is first-come, first-served.
@property (nonatomic, copy, nullable) NSString *viewCookie;
/// As above, but sets a random cookie. Not guaranteed to be cryptographically secure.
- (void) setRandomViewCookie;

// Launching a client application
/// Launches and controls a Glk client application
- (void) launchClientApplication: (NSString*) launchPath
				   withArguments: (nullable NSArray<NSString*>*) appArgs;
/// Terminates the client application
- (void) terminateClient;
/// Sets the input stream
- (void) setInputStream: (id<GlkStream>) stream;
/// Sets the input stream to be input from the given file URL
- (void) setInputFileURL: (NSURL*) filename;
/// Adds a keyed stream that the client can obtain if necessary
- (void) addStream: (id<GlkStream>) stream
		   withKey: (NSString*) streamKey;
/// Adds a keyed stream that reads from the specified filename
- (void) addInputFilename: (NSString*) filename
				  withKey: (NSString*) streamKey;
/// Adds a keyed stream that reads from the specified filename
- (void) addInputFileURL: (NSURL*) filename
				 withKey: (NSString*) streamKey;

@property (nonatomic, strong) id<GlkStream> inputStream;

/// Stream created before the task was initialised (used, for example, for specifying which file was double-clicked on)
- (byref id<GlkStream>) inputStream;

// Writing log messages
/// If the client supports logging, then tell it to display the specified log message
- (void) logMessage: (NSString*) message
		 withStatus: (GlkLogStatus) status;

// The delegate
/// The delegate for this view. Delegates are not retained.
@property (weak, nullable) IBOutlet id<GlkViewDelegate> delegate;

// Events
/// Note that Arrange events are merged if not yet claimed
- (void) queueEvent: (GlkEvent*) event;
/// Called by views to indicate that their app-side data has gone out of date (eg because they are now a different size)
- (void) requestClientSync;

// Preferences
/// Set before this view has attached to a client for the best effect
@property (strong) GlkPreferences* preferences;
/// Current styles
- (NSMutableDictionary*) stylesForWindowType: (unsigned) type;

// Managing images
/// Retrieves the image with the given identifier, asking the client process if necessary
- (nullable NSImage*) imageWithIdentifier: (unsigned) imageId;
/// Retrieves a flipped variant of an image with the given identifier (works around a really annoying Cocoa design flaw, at the expense of storing the image twice)
- (nullable NSImage*) flippedImageWithIdentifier: (unsigned) imageId;

// Dealing with line history
/// Adds a line history event to this view
- (void) addHistoryItem: (NSString*) inputLine
		forWindowWithId: (glui32) windowId;
/// Retrieves the previous history item
@property (nullable, readonly, copy) NSString *previousHistoryItem;
/// Retrieves the next history item
@property (nullable, readonly, copy) NSString *nextHistoryItem;
/// Causes the history position to move to the end
- (void) resetHistoryPosition;

// Layout
/// Forces a layout operation if it's required
- (void) performLayoutIfNecessary;
/// The scale factor of this view and any subview (resizing fonts, etc)
@property (nonatomic) CGFloat scaleFactor;
/// Sets up the border width for new pair windows
- (void) setBorderWidth: (CGFloat) borderWidth;

// Dealing with [ MORE ] prompts
/// \c YES if this CocoaGlk window should always page on more
@property BOOL alwaysPageOnMore;
/// True if any windows are waiting on a [ MORE ] prompts
@property (nonatomic, readonly) BOOL morePromptsPending;
/// Causes all windows that require it to page forwards (returns \c NO if no windows actually needed paging)
- (BOOL) pageAll;
- (void) showMoreWindow;
- (void) hideMoreWindow;

// Various UI events
/// Perform a tab action from the specified GlkWindow (ie, changing focus)
- (void) performTabFrom: (GlkWindow*) window
				forward: (BOOL) forward;
/// Tries to set the first responder again
- (BOOL) setFirstResponder;

// Automation
/// Adds an automation object to receive game and user output events
- (void) addOutputReceiver: (id<GlkAutomation>) receiver;
/// Adds an automation object to receive notifications about when it can sensibly send input to the game (if there is an input receiver, input through the UI is disabled)
- (void) addInputReceiver: (id<GlkAutomation>) receiver;

/// Removes an automation object from input and/or output duties
- (void) removeAutomationObject: (id<GlkAutomation>) receiver;

/// Returns true if there are windows waiting for input (ie, a sendCharacters event will succeed)
@property (nonatomic) BOOL canSendInput;
/// Sends the specified characters to the given window number as a line or character input event
- (int) sendCharacters: (NSString*) characters
			  toWindow: (int) window;
/// Sends a mouse click at the specified position to the given window number
- (int) sendClickAtX: (int) xpos
				   Y: (int) ypos
			toWindow: (int) window;

/// Request from a window object to send characters to the automation system
- (void) automateStream: (id<GlkStream>) stream
			  forString: (NSString*) string;
@end

///
/// Functions that a view delegate can provide
///
@protocol GlkViewDelegate <NSObject>
@optional

/// Set to return \c YES to get rid of the CocoaGlk logo
@property (nonatomic, readonly) BOOL disableLogo;
/// If non-nil, then this will be the logo displayed instead of 'CocoaGlk'
@property (readonly, nullable, copy) NSImage *logo;
/// A description of what is running in this window (or nil)
@property (nonatomic, readonly, copy, nullable) NSString *taskDescription;

/// Called to show warnings, etc
- (void) showStatusText: (NSString*) status;
/// Called to show errors
- (void) showError: (NSString*) error;
/// Called to show general purpose log messages
- (void) showLogMessage: (NSString*) message
			 withStatus: (GlkLogStatus) status;

/// Called when the Glk task starts
- (void) taskHasStarted;
/// Called when the Glk task finishes (usually, may not be called under some circumstances)
- (void) taskHasFinished;
/// Additionally called when the task crashes
- (void) taskHasCrashed;

/// This works out the 'real' path for a file requested by name (default is to remove control characters and stick it on the Desktop)
- (nullable NSString*) pathForNamedFile: (NSString*) name;
/// This works out the 'preferred' directory for save files. CocoaGlk will use it's own judgement if this returns nil
- (nullable NSURL*) preferredSaveDirectory;
/// Called to give the delegate a chance to store the final directory chosen for a save in the preferences.
- (void) savePreferredDirectory: (nullable NSString*) finalDir;

/// The delegate can override this to provide custom saving behaviour for its files. This should return \c YES if the delegate is going to handle the event or \c NO otherwise
- (BOOL) promptForFilesForUsage: (NSString*) usage
					 forWriting: (BOOL) writing
						handler: (id<GlkFilePrompt>) handler
			 preferredDirectory: (nullable NSURL*) preferredDirectory;

@end

NS_ASSUME_NONNULL_END

#endif
