//
//  GlkView.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkSessionProtocol.h>
#import <GlkView/GlkWindow.h>
#import <GlkView/GlkEvent.h>
#import <GlkView/GlkPreferences.h>
#import <GlkView/GlkStyle.h>

@protocol GlkAutomation;

typedef enum GlkLogStatus {
	GlkLogRoutine,								// Routine log message
	GlkLogInformation,							// Informational log message
	GlkLogCustom,								// Custom log message (from the game, for example)
	GlkLogWarning,								// Warning log message
	GlkLogError,								// Error log message
	GlkLogFatalError,							// Fatal error log message
} GlkLogStatus;

//
// Base class for CocoaGlk: a view object that an application can embed in order to run Glk client applications
//
@interface GlkView : NSView<GlkSession, GlkBuffer, GlkEventReceiver>

// Some shared settings
+ (NSImage*) defaultLogo;										// Image displayed while there is no root window

// Setting up for launch
- (void) setViewCookie: (NSString*) cookie;						// If cookie is non-nil, a client application must know the cookie to connect to this view. If nil, this view is first-come, first-served.
- (void) setRandomViewCookie;									// As above, but sets a random cookie. Not guaranteed to be cryptographically secure.

// Launching a client application
- (void) launchClientApplication: (NSString*) launchPath		// Launches and controls a Glk client application
				   withArguments: (NSArray*) appArgs;
- (void) terminateClient;										// Terminates the client application
- (void) setInputStream: (NSObject<GlkStream>*) stream;			// Sets the input stream
- (void) setInputFilename: (NSString*) filename;				// Sets the input stream to be input from the given file
- (void) addStream: (NSObject<GlkStream>*) stream				// Adds a keyed stream that the client can obtain if necessary
		   withKey: (NSString*) streamKey;
- (void) addInputFilename: (NSString*) filename					// Adds a keyed stream that reads from the specified filename
				  withKey: (NSString*) streamKey;

// Writing log messages
- (void) logMessage: (NSString*) message						// If the client supports logging, then tell it to display the specified log message
		 withStatus: (GlkLogStatus) status;

// The delegate
- (void) setDelegate: (id) delegate;							// Sets the delegate for this view. Delegates are not retained.

// Events
- (void) queueEvent: (GlkEvent*) event;							// Note that Arrange events are merged if not yet claimed
- (void) requestClientSync;										// Called by views to indicate that their app-side data has gone out of date (eg because they are now a different size)

// Preferences
- (void) setPreferences: (GlkPreferences*) prefs;				// Call before this view has attached to a client for the best effect
- (NSMutableDictionary*) stylesForWindowType: (unsigned) type;	// Current styles

// Managing images
- (NSImage*) imageWithIdentifier: (unsigned) imageId;			// Retrieves the image with the given identifier, asking the client process if necessary
- (NSImage*) flippedImageWithIdentifier: (unsigned) imageId;	// Retrieves a flipped variant of an image with the given identifier (works around a really annoying Cocoa design flaw, at the expense of storing the image twice)

// Dealing with line history
- (void) addHistoryItem: (NSString*) inputLine					// Adds a line history event to this view
		forWindowWithId: (glui32) windowId;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *previousHistoryItem;								// Retrieves the previous history item
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *nextHistoryItem;									// Retrieves the next history item
- (void) resetHistoryPosition;									// Causes the history position to move to the end

// Layout
- (void) performLayoutIfNecessary;								// Forces a layout operation if it's required
- (void) setScaleFactor: (float) scale;							// Sets the scale factor of this view and any subview (resizing fonts, etc)
- (void) setBorderWidth: (float) borderWidth;					// Sets up the border width for new pair windows

// Dealing with [ MORE ] prompts				// YES if this CocoaGlk window should always page on more
@property (NS_NONATOMIC_IOSONLY) BOOL alwaysPageOnMore;										// Ditto
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL morePromptsPending;									// True if any windows are waiting on a [ MORE ] prompts
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL pageAll;												// Causes all windows that require it to page forwards (returns NO if no windows actually needed paging)
- (void) showMoreWindow;
- (void) hideMoreWindow;

// Various UI events
- (void) performTabFrom: (GlkWindow*) window					// Perform a tab action from the specified GlkWindow (ie, changing focus)
				forward: (BOOL) forward;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL setFirstResponder;										// Tries to set the first responder again

// Automation
- (void) addOutputReceiver: (NSObject<GlkAutomation>*) receiver;		// Adds an automation object to receive game and user output events
- (void) addInputReceiver: (NSObject<GlkAutomation>*) receiver;			// Adds an automation object to receive notifications about when it can sensibly send input to the game (if there is an input receiver, input through the UI is disabled)

- (void) removeAutomationObject: (NSObject<GlkAutomation>*) receiver;	// Removes an automation object from input and/or output duties

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL canSendInput;											// Returns true if there are windows waiting for input (ie, a sendCharacters event will succeed)
- (int) sendCharacters: (NSString*) characters					// Sends the specified characters to the given window number as a line or character input event
			  toWindow: (int) window;
- (int) sendClickAtX: (int) xpos								// Sends a mouse click at the specified position to the given window number
				   Y: (int) ypos
			toWindow: (int) window;

- (void) automateStream: (NSObject<GlkStream>*) stream			// Request from a window object to send characters to the automation system
			  forString: (NSString*) string;
@end

//
// Functions that a view delegate can provide
//

@interface NSObject(GlkViewDelegate)

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL disableLogo;											// Set to return YES to get rid of the CocoaGlk logo
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSImage *logo;												// If non-nil, then this will be the logo displayed instead of 'CocoaGlk'
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *taskDescription;									// A description of what is running in this window (or nil)

- (void) showStatusText: (NSString*) status;					// Called to show warnings, etc
- (void) showError: (NSString*) error;							// Called to show errors
- (void) showLogMessage: (NSString*) message					// Called to show general purpose log messages
			 withStatus: (GlkLogStatus) status;

- (void) taskHasStarted;										// Called when the Glk task starts
- (void) taskHasFinished;										// Called when the Glk task finishes (usually, may not be called under some circumstances)
- (void) taskHasCrashed;										// Additionally called when the task crashes

- (NSString*) pathForNamedFile: (NSString*) name;				// This works out the 'real' path for a file requested by name (default is to remove control characters and stick it on the Desktop)
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *preferredSaveDirectory;							// This works out the 'preferred' directory for save files. CocoaGlk will use it's own judgement if this returns nil
- (void) savePreferredDirectory: (NSString*) finalDir;			// Called to give the delegate a chance to store the final directory chosen for a save in the preferences.

- (BOOL) promptForFilesForUsage: (NSString*) usage				// The delegate can override this to provide custom saving behaviour for its files. This should return YES if the delegate is going to handle the event or NO otherwise
					 forWriting: (BOOL) writing
						handler: (NSObject<GlkFilePrompt>*) handler
			 preferredDirectory: (NSString*) preferredDirectory;

@end

#import <GlkView/GlkAutomation.h>
