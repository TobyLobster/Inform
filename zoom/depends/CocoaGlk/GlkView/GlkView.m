//
//  GlkView.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#include <unistd.h>

#import "GlkView.h"
#import "glk.h"

#import "GlkWindow.h"
#import "GlkPairWindow.h"
#import "GlkTextWindow.h"
#import "GlkTextGridWindow.h"
#import "GlkGraphicsWindow.h"
#import "GlkArrangeEvent.h"
#import "GlkFileRef.h"
#import "GlkHub.h"
#import "GlkFileStream.h"


#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4

#define NSAccessibilityDescriptionAttribute NSAccessibilityHelpAttribute

#endif

@interface GlkView(Private)

- (void) setFirstResponder;

@end

@implementation GlkView

// = Initialisation =

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
		rootWindow = nil;
		glkWindows = [[NSMutableDictionary alloc] init];
		
		glkStreams = [[NSMutableDictionary alloc] init];
		
		events = [[NSMutableArray alloc] init];
		
		prefs = [[GlkPreferences sharedPreferences] retain];
		styles = nil;
		
		imageDictionary = [[NSMutableDictionary alloc] init];
		
		inputHistory = [[NSMutableArray alloc] init];
		
		outputReceivers = [[NSMutableArray alloc] init];
		inputReceivers = [[NSMutableArray alloc] init];
		
		extensionsForUsage = [[NSMutableDictionary alloc] init];

        listener = nil;

		scaleFactor = 1.0f;
		borderWidth = 2.0f;
    }
    
	return self;
}

- (void) dealloc {
	[rootWindow setEventTarget: nil];						// Event targets are not retained, so we have to do this in case some more events arrive after we've gone
	
	if (viewCookie) {
		[[GlkHub sharedGlkHub] unregisterSession: self];	// We don't really want to hang around
	}
	
	[rootWindow release]; rootWindow = nil;
	[lastRootWindow release]; lastRootWindow = nil;
	[glkWindows release]; glkWindows = nil;
	[lastPanel release]; lastPanel = nil;
	
	[glkStreams release]; glkStreams = nil;	
	[inputStream release]; inputStream = nil;
	[extraStreamDictionary release]; extraStreamDictionary = nil;
	
	[arrangeEvent release]; arrangeEvent = nil;
	[events release]; events = nil;
	[listener release]; 
	//NSLog(@"self = %@ listener %@ released (dealloc)", self, listener); 
	listener = nil;
	
	[fadeTimer invalidate];
	[fadeTimer release]; fadeTimer = nil;
	[fadeStart release];
	
	[extensionsForUsage release];
	
	if (logoWindow) {
		[[logoWindow parentWindow] removeChildWindow: logoWindow]; 
		[logoWindow release];
		logoWindow = nil;
	}
	
	[promptHandler release]; promptHandler = nil;
	[allowedFiletypes release]; allowedFiletypes = nil;
	
	[prefs release]; prefs = nil;
	[styles release]; styles = nil;
	
	[subtask release]; subtask = nil;
	[viewCookie release]; viewCookie = nil;
	
	[imgSrc release]; imgSrc = nil;
	[imageDictionary release]; imageDictionary = nil;
	[flippedImageDictionary release]; flippedImageDictionary = nil;
	
	[inputReceivers release];
	[outputReceivers release];

	[inputHistory release];
	
	if (windowPositionCache) [windowPositionCache release];
	if (windowIdCache) [windowIdCache release];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[super dealloc];
}

// = Shutting down the timer =

- (void) killFadeTimer {
	if (fadeTimer) {
		[fadeTimer invalidate];
		[[NSRunLoop currentRunLoop] performSelector: @selector(finishKillingTimer) 
											 target: self
										   argument: nil
											  order: 128
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
	}
}

- (void) finishKillingTimer {
	[[self retain] autorelease];
	
	if (fadeTimer) {
		[fadeTimer release];
		[self autorelease];
		fadeTimer = nil;
	}
	
	if (logoWindow) {
		[[logoWindow parentWindow] removeChildWindow: logoWindow];
		[logoWindow orderOut: self];
		[logoWindow release];
		logoWindow = nil;		
	}
}

// = The CocoaGlk logo =

+ (NSImage*) defaultLogo {
	// This image is used while there is no root window active
	static NSImage* defaultLogo = nil;
	
	if (!defaultLogo) {
		defaultLogo = [[NSImage alloc] initWithContentsOfFile: [[NSBundle bundleForClass: [self class]] pathForImageResource: @"logo"]];
	}
	
	return defaultLogo;
}

- (NSImage*) customLogo {
	if (delegate && [delegate respondsToSelector: @selector(logo)]) {
		return [delegate logo];
	}	
	
	return nil;
}

- (NSImage*) logo {
	NSImage* result = [self customLogo];
	
	if (result == nil) result = [[self class] defaultLogo];
	return result;
}

- (void) positionLogoWindow {
	// Position relative to the window
	NSRect frame = [self convertRect: [self bounds] toView: nil];
	NSRect windowFrame = [[self window] frame];
	
	// Position on screen
	frame.origin.x += windowFrame.origin.x;
	frame.origin.y += windowFrame.origin.y;
	
	// Position the logo window
	[logoWindow setFrame: frame
				 display: YES];
}

- (void) showLogoWindow {
	// Fading the logo out like this stops it from flickering
	waitTime = fadeTime = 0.2;

	if ([self disableLogo]) return;
	if (logoWindow) return;
	if (fadeTimer) return;
	
	if ([self customLogo] != nil) {
		waitTime = 1.0;
		fadeTime = 0.5;
	}
	
	// Don't show this if this view is not on the screen
	if ([self window] == nil) return;
	if (![[self window] isVisible]) return;
	if ([self superview] == nil) return;
	
	// Create the window
	logoWindow = [[NSWindow alloc] initWithContentRect: [self frame]				// Gets the size, we position later
											 styleMask: NSBorderlessWindowMask
											   backing: NSBackingStoreBuffered
												 defer: YES];
	[logoWindow setOpaque: NO];
	[logoWindow setBackgroundColor: [NSColor clearColor]];
	
	// Create the image view that goes inside
	NSImageView* fadeContents = [[NSImageView alloc] initWithFrame: [[logoWindow contentView] frame]];
	
	[fadeContents setImage: [self logo]];
	[logoWindow setContentView: [fadeContents autorelease]];
	
	fadeTimer = [NSTimer timerWithTimeInterval: waitTime
										target: self
									  selector: @selector(startToFadeLogo)
									  userInfo: nil
									   repeats: NO];
	[fadeTimer retain]; [self retain];
	[[NSRunLoop currentRunLoop] addTimer: fadeTimer
								 forMode: NSDefaultRunLoopMode];
	
	// Position the window correctly
	[self positionLogoWindow];
	
	// Show the window
	[logoWindow orderFront: self];
	[[self window] addChildWindow: logoWindow
						  ordered: NSWindowAbove];
}

- (void) startToFadeLogo {
	if (fadeTimer) {
		[fadeTimer invalidate];
		[fadeTimer release];
		[self autorelease];
	}
	fadeTimer = nil;
	
	fadeTimer = [NSTimer timerWithTimeInterval: 0.01
										target: self
									  selector: @selector(fadeLogo)
									  userInfo: nil
									   repeats: YES];
	[fadeTimer retain]; [self retain];
	[[NSRunLoop currentRunLoop] addTimer: fadeTimer
								 forMode: NSDefaultRunLoopMode];
	
	[fadeStart release];
	fadeStart = [[NSDate date] retain];
}

- (void) fadeLogo {
	float timePassed = [[NSDate date] timeIntervalSinceDate: fadeStart];
	float fadeAmount = timePassed/fadeTime;
	
	if (fadeAmount < 0 || fadeAmount > 1) {
		// Finished fading: get rid of the window + the timer
		[fadeTimer invalidate];
		[fadeTimer release];
		[self autorelease];
		fadeTimer = nil;
		
		[[logoWindow parentWindow] removeChildWindow: logoWindow];
		[logoWindow orderOut: self];
		[logoWindow release];
		logoWindow = nil;
		
		[fadeStart release];
		fadeStart = nil;
	} else {
		fadeAmount = -2.0*fadeAmount*fadeAmount*fadeAmount + 3.0*fadeAmount*fadeAmount;
		
		[logoWindow setAlphaValue: 1.0 - fadeAmount];
	}
}

- (void) removeFromSuperview {
	[[self retain] autorelease];
	[super removeFromSuperview];
	[self killFadeTimer];
}

- (void) removeFromSuperviewWithoutNeedingDisplay {
	[[self retain] autorelease];
	[super removeFromSuperviewWithoutNeedingDisplay];
	[self killFadeTimer];
}

// = Drawing =

- (void)drawRect:(NSRect)rect {
	if (rootWindow != nil) return;
	
	// MAYBE: allow the game to provide its own logo if it wants
	if (![self disableLogo]) {
		NSImage* logo = [self logo];

		// Position the logo
		NSSize logoSize = [logo size];
		NSRect logoPos;
		NSRect logoSource;
	
		logoPos.size = logoSize;
		logoPos.origin = NSMakePoint(floorf(rect.origin.x + (rect.size.width - logoSize.width)/2.0),
									 floorf(rect.origin.y + (rect.size.height - logoSize.height)/2.0));
	
		logoSource.size = logoSize;
		logoSource.origin = NSMakePoint(0,0);
	
		[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
		[logo drawInRect: logoPos
				fromRect: logoSource
			   operation: NSCompositeSourceOver
				fraction: 1.0];
	}
}

- (void) setFrame: (NSRect) newFrame {
	[super setFrame: newFrame];
	
	// Lay out the root window
	[rootWindow layoutInRect: [self bounds]];
	
	// Queue an event to tell the client that things are now mysteriously different
	[self queueEvent: [[[GlkArrangeEvent alloc] initWithGlkWindow: rootWindow] autorelease]];
		
	// Move the transparent logo window if it exists
	if (logoWindow) [self positionLogoWindow];
}

// = The delegate =

- (void) setDelegate: (id) newDelegate {
	delegate = newDelegate;
}

- (BOOL) disableLogo {
	if (delegate && [delegate respondsToSelector: @selector(disableLogo)]) {
		return [delegate disableLogo];
	} else {
		return NO;
	}
}

- (void) showStatusText: (NSString*) status {
	if (delegate && [delegate respondsToSelector: @selector(showStatusText:)]) {
		[delegate showStatusText: status];
	}
}

- (void) showError: (in bycopy NSString*) error {
	[self logMessage: [NSString stringWithFormat: @"Client error: %@", error]
		  withStatus: GlkLogError];
	
	if (delegate && [delegate respondsToSelector: @selector(showError:)]) {
		[delegate showError: error];
	} else if ([self window]) {
		NSBeginAlertSheet([[NSBundle mainBundle] localizedStringForKey: @"Glk Error"
																 value: @"Glk Error"
																 table: nil],
						  [[NSBundle mainBundle] localizedStringForKey: @"Cancel"
																 value: @"Cancel"
																 table: nil],
						  nil, nil, [self window], self, nil, nil, nil,
						  @"%@", [[NSBundle mainBundle] localizedStringForKey: error
                                                                        value: error
                                                                        table: nil]);
	} else {
		NSLog(@"Glk error: %@", error);
	}
}

- (void) showWarning: (in bycopy NSString*) warning {
	[self logMessage: [NSString stringWithFormat: @"Client warning: %@", warning]
		  withStatus: GlkLogWarning];

	NSString* warn = [[NSBundle mainBundle] localizedStringForKey: @"Warning:"
															value: @"Warning:"
															table: nil];
	warn = [warn stringByAppendingString: @" "];
	
	[self showStatusText: [warn stringByAppendingString: [[NSBundle mainBundle] localizedStringForKey: warning
																								value: warning
																								table: nil]]];
}

- (void) taskHasStarted {
	if (delegate && [delegate respondsToSelector: @selector(taskHasStarted)]) {
		[delegate taskHasStarted];
	}
}

- (void) taskHasFinished {
	// Report any crashes that may have occurred
	BOOL crashed = NO;
	if (subtask && ![subtask isRunning] && [subtask terminationStatus] > 1) {
		[self logMessage: [NSString stringWithFormat: @"Client crashed with code %i", [subtask terminationStatus]]
			  withStatus: GlkLogFatalError];
		crashed = YES;
	}
	
	// Tell all of the windows that the task has finished
	[rootWindow taskFinished];
	
	// Inform the delegate
	if (delegate && [delegate respondsToSelector: @selector(taskHasFinished)]) {
		[delegate taskHasFinished];
	}
	if (delegate && crashed && [delegate respondsToSelector: @selector(taskHasCrashed)]) {
		[delegate taskHasCrashed];
	}
}

- (NSString*) pathForNamedFile: (NSString*) name {
	if (delegate && [delegate respondsToSelector: @selector(pathForNamedFile:)]) {
		return [delegate pathForNamedFile: name];
	} else {
		if ([name length] <= 0) return NULL;
		
		NSMutableString* res = [name mutableCopy];
		
		// Maximum filename length of 63 characters
		if ([res length] > 63) {
			[res deleteCharactersInRange: NSMakeRange(63, [res length]-63)];
		}
		
		// Replace all 'bad' characters in res with ':'
		int x;
		for (x=0; x<[res length]; x++) {
			unichar chr = [res characterAtIndex: x];
			
			if (chr < 32 || chr > 126 || chr == '/' || (x==0 && chr == '.')) {
				[res replaceCharactersInRange: NSMakeRange(x, 1)
								   withString: @":"];
			}
		}
		
		// Full path becomes ~/Desktop/<name>.glk
		NSString* fullPath = [@"~" stringByAppendingPathComponent: [res stringByAppendingPathExtension: @"glkdata"]];
		
		[res release]; res = nil;
		
		return fullPath;
	}
}

// = Events =

- (void) queueEvent: (GlkEvent*) event {
	if ([event type] == evtype_Arrange) {
		if (arrangeEvent) {
			// Merge with the previous arrange event
			GlkWindow* origWin = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: [arrangeEvent windowIdentifier]]];
			GlkWindow* newWin = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: [event windowIdentifier]]];
			
			if (origWin != rootWindow && origWin != newWin && [origWin identifier] != [newWin identifier]) {
				// Create a new arrangement event using the root window
				// Could look for the common ancestor, but this way is easier
				GlkEvent* newEvent = [[GlkArrangeEvent alloc] initWithGlkWindow: rootWindow];
				
				unsigned evtIndex = [events indexOfObjectIdenticalTo: arrangeEvent];
				
				if (evtIndex != NSNotFound) {
					[events replaceObjectAtIndex: evtIndex
									  withObject: newEvent];
					
					[arrangeEvent release];
					arrangeEvent = [newEvent retain];
				} else {
					NSLog(@"Warning: arrangement event has gone walkabout");
				}
				
				[newEvent release];
			}
			
			return;
		} else {
			// This becomes the arrange event
			arrangeEvent = [event retain];
		}
	}
	
	[events addObject: event];
	
	if (listener) {
		// Notify the listener
		
		// We retain the listener here as there is a non-zero chance of the client waiting on a
		// call to setEventListener: here, which will cause a segfault if it releases the current
		// listener (seems to be a bug in NSDistantObject)
		[listener retain];  
		//NSLog(@"self=%@ Listener %x retained", self, (int)(void*)listener);
        [listener eventReady: syncCount];
		[listener release];
		//NSLog(@"self=%@ Listener %@ released", self, listener);
	}
}

- (int) synchronisationCount {
	return syncCount;
}

- (void) requestClientSync {
	syncCount++;
}

// = Preferences =

- (NSMutableDictionary*) stylesForWindowType: (unsigned) type {
	if (!prefs) {
		// Construct the preference object if necessary
		prefs = [[GlkPreferences sharedPreferences] retain];
	}
	
	if (!styles) {
		// Create the styles dictionary if necessary
		styles = [[NSMutableDictionary alloc] init];
	}
	
	NSMutableDictionary* res = [styles objectForKey: [NSNumber numberWithUnsignedInt: type]];
	if (!res) {
		// Create the dictionary for this wintype if necessary
		res = [[NSMutableDictionary alloc] initWithDictionary: [prefs styles]
													copyItems: YES];
		
		[styles setObject: res
				   forKey: [NSNumber numberWithUnsignedInt: type]];
	} else {
		[res retain];
	}
	
	return [res autorelease];
}

- (void) setPreferences: (GlkPreferences*) newPrefs {
	[prefs release];
	prefs = [newPrefs retain];
}

// = Setting up for launch =

- (void) setViewCookie: (NSString*) cookie {
	[viewCookie release];
	viewCookie = [cookie copy];
	
	[self logMessage: @"View cookie set"
		  withStatus: GlkLogRoutine];
}

- (void) setRandomViewCookie {
	unichar randomCookie[16];
	int x;
	
	for (x=0; x<16; x++) {
		randomCookie[x] = random()%94 + 32;
	}
	
	[self setViewCookie: [NSString stringWithCharacters: randomCookie
												 length: 16]];
}

// = Launching a client application =

- (void) launchClientApplication: (NSString*) executableName
				   withArguments: (NSArray*) appArgs {
	// We can't launch more than one client with this view
	// This test is not comprehensive. It's possible for a client to be connected and have no root window
	if (subtask || rootWindow != nil || running) {
		[NSException raise: @"GlkViewClientAlreadyConnectedException"
					format: @"A client task is already connected to a view, but launchClientApplication: was called"];
	}
	
	[self logMessage: [NSString stringWithFormat: @"Launching client: %@", [executableName lastPathComponent]]
		  withStatus: GlkLogInformation];
	
	// We must have a view cookie to perform this operation
	if (!viewCookie) [self setRandomViewCookie];
	
	// Register with the hub
	[[GlkHub sharedGlkHub] registerSession: self
								withCookie: viewCookie];
	
	// Create the task
	subtask = [[NSTask alloc] init];
	
	// The arguments
	NSMutableArray* args = [[NSMutableArray alloc] initWithObjects: 
		@"-hubname", [[GlkHub sharedGlkHub] hubName], 
		nil];
	if (appArgs) [args addObjectsFromArray: appArgs];
	
	// The environment
	NSMutableDictionary* env = [[[NSProcessInfo processInfo] environment] mutableCopy];
	[env setObject: [[GlkHub sharedGlkHub] hubCookie]
			forKey: @"GlkHubCookie"];
	[env setObject: viewCookie
			forKey: @"GlkSessionCookie"];

	// Prepare for launch
	[subtask setLaunchPath: executableName];
	[subtask setArguments: args];
	[subtask setEnvironment: env];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(subtaskHasFinished:)
												 name: NSTaskDidTerminateNotification
											   object: subtask];
	
	// Go!
	[subtask launch];
	running = YES;
	
	// Tidy up
	[args release];
	[env release];
}

- (void) terminateClient {
	if (!subtask) {
		//NSLog(@"Oops: terminateClient can't sensibly be called if the client isn't being controlled by the GlkView");
		return;
	}

	[self logMessage: @"Terminating Glk client"
		  withStatus: GlkLogInformation];

	[subtask terminate];
}

- (void) addStream: (NSObject<GlkStream>*) stream 
		   withKey: (NSString*) streamKey {
	if (!extraStreamDictionary) {
		extraStreamDictionary = [[NSMutableDictionary alloc] init];
	}
	
	[extraStreamDictionary setObject: stream
							  forKey: streamKey];
	
	[self logMessage: [NSString stringWithFormat: @"Creating stream with key '%@'", streamKey]
		  withStatus: GlkLogRoutine];
}

- (void) addInputFilename: (NSString*) filename 
				  withKey: (NSString*) streamKey {
	if (!extraStreamDictionary) {
		extraStreamDictionary = [[NSMutableDictionary alloc] init];
	}
	
	[extraStreamDictionary setObject: [[[GlkFileStream alloc] initForReadingWithFilename: filename] autorelease]
							  forKey: streamKey];
	
	[self logMessage: [NSString stringWithFormat: @"Creating stream to read data from '%@' with key '%@'", filename, streamKey]
		  withStatus: GlkLogRoutine];
}

- (void) setInputStream: (NSObject<GlkStream>*) stream {
	[inputStream release]; inputStream = nil;
	inputStream = [stream retain];
	
	[self logMessage: @"Reading data from an internal stream"
		  withStatus: GlkLogRoutine];
}

- (void) setInputFilename: (NSString*) filename {
	[inputStream release]; inputStream = nil;
	inputStream = [[GlkFileStream alloc] initForReadingWithFilename: filename];
	
	[self logMessage: [NSString stringWithFormat: @"Will read data from: %@", filename]
		  withStatus: GlkLogRoutine];
}

- (void) subtaskHasFinished: (NSNotification*) not {
	if (running) {
		[self clientHasFinished];
	}
	
	[[self retain] autorelease];
	[[GlkHub sharedGlkHub] unregisterSession: self];
	[subtask release]; subtask = nil;
}

// = GlkSession implementations =

// Housekeeping

- (void) clientHasStarted: (pid_t) processId {
	running = YES;
	[viewCookie release]; viewCookie = nil;						// Don't want to re-use the cookie
	
	[self logMessage: @"Glk client has started"
		  withStatus: GlkLogRoutine];
	
	[self taskHasStarted];
}

- (void) clientHasFinished {
    listener = nil;
	running = NO;
	
	[self logMessage: @"Glk client has terminated"
		  withStatus: GlkLogRoutine];
		
	[self taskHasFinished];
}

// Buffering

- (void) performOperationsFromBuffer: (in bycopy GlkBuffer*) buffer {
	if (flushing) {
		NSLog(@"WARNING: buffer flush deferred to avoid out-of-order data");
		
		[[NSRunLoop currentRunLoop] performSelector: @selector(performOperationsFromBuffer:)
											 target: self
										   argument: buffer
											  order: 64
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
		return;
	}
	
	[self showStatusText: @""];
	
	flushing = YES;
	
	[lastRootWindow release];
	lastRootWindow = [rootWindow retain];
	
	[rootWindow bufferIsFlushing];

	[buffer flushToTarget: self];
	
	if (windowsNeedLayout && rootWindow != nil) {
		if (lastRootWindow != rootWindow) {
			[lastRootWindow removeFromSuperviewWithoutNeedingDisplay];
			[self addSubview: rootWindow];
			[self setNeedsDisplay: YES];
		}
		
		[rootWindow layoutInRect: [self bounds]];
		windowsNeedLayout = NO;
	}
	
	[rootWindow bufferHasFlushed];
	
	flushing = NO;
}

- (void) performLayoutIfNecessary {
	if (windowsNeedLayout && rootWindow != nil) {
		if (lastRootWindow != rootWindow) {
			[lastRootWindow removeFromSuperviewWithoutNeedingDisplay];
			[self addSubview: rootWindow];
			[self setNeedsDisplay: YES];
		}
		
		[rootWindow layoutInRect: [self bounds]];
		windowsNeedLayout = NO;
	}	
}

- (void) setScaleFactor: (float) scale {
	scaleFactor = scale;
	[rootWindow setScaleFactor: scale];

	windowsNeedLayout = YES;
	[self performLayoutIfNecessary];
}

- (void) updateBorderWidthFor: (GlkWindow*) win {
	if ([win isKindOfClass: [GlkPairWindow class]]) {
		[(GlkPairWindow*)win setBorderWidth: borderWidth];
		[self updateBorderWidthFor: [(GlkPairWindow*)win leftWindow]];
		[self updateBorderWidthFor: [(GlkPairWindow*)win rightWindow]];
	}
}

- (void) setBorderWidth: (float) newBorderWidth {
	// Do nothing if the border is already the right size
	if (newBorderWidth == borderWidth) return;
	
	// Update the border width, and the width of any existing windows
	borderWidth = newBorderWidth;
	[self updateBorderWidthFor: rootWindow];
	
	// Perform any layout that's necessary
	windowsNeedLayout = YES;
	[self performLayoutIfNecessary];
}

// Streams

- (byref NSObject<GlkStream>*) streamForWindowIdentifier: (unsigned) windowId {
	GlkWindow* window = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowId]];
	
	if (window) {
		return window;
	} else {
		return nil;
	}
}

- (byref NSObject<GlkStream>*) inputStream {
	return inputStream;
}

- (byref NSObject<GlkStream>*) streamForKey: (in bycopy NSString*) key {
	return [extraStreamDictionary objectForKey: key];
}

// Styles

- (glui32) measureStyle: (glui32) styl
				   hint: (glui32) hint
			   inWindow: (glui32) windowId {
	// Get the window
	GlkWindow* window = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowId]];
	
	if (!window) {
		NSLog(@"measureStyle:hint:inWindow: called with an invalid window ID");
		return 0;
	}
	
	// Get the style
	GlkStyle* style = [window style: styl];
	if (!style) style = [GlkStyle style];
	
	// Perform the measurement
	switch (hint) {
		case stylehint_BackColor:
		case stylehint_TextColor:
		{
			NSColor* col;
			
			if (hint == stylehint_BackColor) {
				col = [style backColour];
			} else {
				col = [style textColour];
			}
			
			int r = floorf(255.0 * [col redComponent]);
			int g = floorf(255.0 * [col greenComponent]);
			int b = floorf(255.0 * [col blueComponent]);
			
			return (r<<16)|(g<<8)|(b);
		}
			
		case stylehint_Indentation:
			return [style indentation];
			
		case stylehint_Justification:
			switch ([style justification]) {
				default:
				case NSLeftTextAlignment:
					return stylehint_just_LeftFlush;
				case NSRightTextAlignment:
					return stylehint_just_RightFlush;
				case NSCenterTextAlignment:
					return stylehint_just_Centered;
				case NSJustifiedTextAlignment:
					return stylehint_just_LeftRight;
			}
			
			return 0;
			
		case stylehint_Oblique:
			return [style oblique]?1:0;
			
		case stylehint_ParaIndentation:
			return [style paraIndentation];
			
		case stylehint_Proportional:
			return [style proportional]?1:0;
			
		case stylehint_ReverseColor:
			return [style reversed]?1:0;
			
		case stylehint_Size:
			// This is a bit pointless, as the units are 'platform-defined'. Therefore we measure our font size in football fields.
			// (Well, FSVO football)
			return [[style proportional]?[prefs proportionalFont]:[prefs fixedFont] pointSize] + [style size];
			
		case stylehint_Weight:
			return [style weight];
		
		default:
			return 0;
	}
}

// Windows

- (GlkSize) sizeForWindowIdentifier: (unsigned) windowId {
	GlkWindow* window = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowId]];
	
	if (window == nil) {
		NSLog(@"Warning: attempt to get size for nonexistent window");
		
		GlkSize erm;
		
		erm.width = 0;
		erm.height = 0;
		
		return erm;
	}
	
	return [window glkSize];
}

// Events

- (bycopy NSObject<GlkEvent>*) nextEvent {
	if ([events count] > 0) {
		// Get the next event from the queue
		GlkEvent* nextEvent = [[[events objectAtIndex: 0] retain] autorelease];
		[events removeObjectAtIndex: 0];
		
		if (nextEvent == arrangeEvent) {
			// If we're reporting an arrangement, free up the arrange event
			[arrangeEvent release];
			arrangeEvent = nil;
		}
		
		return nextEvent;
	} else {
		// No events
		return nil;
	}
}

- (void) setEventListener: (in byref NSObject<GlkEventListener>*) newListener {
    //NSLog(@"self=%@ Listener %@ autoreleased", self, listener);
	[listener autorelease]; listener = nil;
	
	// Inform any input automation objects that if they've got events waiting, then now is the time to fire them
	if (newListener != nil) {
		listener = [newListener retain];
        //NSLog(@"self=%@ Listener %@ retained (new)", self, listener);

		NSEnumerator* inputReceiverEnum = [inputReceivers objectEnumerator];
		NSObject<GlkAutomation>* receiver;
		
		while (receiver = [inputReceiverEnum nextObject]) {
			[receiver viewIsWaitingForInput: self];
		}

		NSEnumerator* outputReceiverEnum = [outputReceivers objectEnumerator];
		
		while (receiver = [outputReceiverEnum nextObject]) {
			[receiver viewWaiting: self];
		}
	}
}

- (void) resetMoreOn: (GlkWindow*) win {
	if (win == nil) return;
	
	if ([win isKindOfClass: [GlkPairWindow class]]) {
		[self resetMoreOn: [(GlkPairWindow*)win leftWindow]];
		[self resetMoreOn: [(GlkPairWindow*)win rightWindow]];
	} else if ([win isKindOfClass: [GlkTextWindow class]]) {
		[(GlkTextWindow*)win resetMorePrompt];
	}
}

- (void) willSelect {
	// Reset the more prompts of all the windows
	[self resetMoreOn: rootWindow];
	
	// Fix the input status of the root window
	[rootWindow fixInputStatus];
	
	// Set up the first responder
	[self setFirstResponder];
}

// Filerefs

- (NSObject<GlkFileRef>*) fileRefWithName: (in bycopy NSString*) name {
	// Turn into a 'real' path
	NSString* path = [self pathForNamedFile: name];
	if (!path) return nil;
	
	[self logMessage: [NSString stringWithFormat: @"Getting named file '%@'; decided on final path of '%@'", name, path]
		  withStatus: GlkLogInformation];
	
	// Then turn into a GlkFileRef
	GlkFileRef* res = [[GlkFileRef alloc] initWithPath: path];
	return [res autorelease];
}

- (NSObject<GlkFileRef>*) tempFileRef {
	NSString* tempDir = NSTemporaryDirectory();
	if (tempDir == nil) return nil;
	
	// Get a temporary file name
	char tempName[25];
	int x;
	
	strcpy(tempName, "cocoaglk_");
   	for (x=strlen(tempName); x<25; x++) 
		tempName[x] = 'X';
	tempName[x] = 0;
	
	mkstemp(tempName);
	
	NSString* tempPath = [tempDir stringByAppendingPathComponent: [NSString stringWithCString: tempName encoding: NSUTF8StringEncoding]];
	
	// Turn into a temporary fileref
	GlkFileRef* res = [[GlkFileRef alloc] initWithPath: tempPath];
	[res setTemporary: YES];
	return [res autorelease];
}

- (bycopy NSArray*) fileTypesForUsage: (in bycopy NSString*) usage {
	// Get the user-set value (if any)
	NSArray* result = [[[extensionsForUsage objectForKey: usage] retain] autorelease];
	if (result) return result;
	
	// Return the defaults if known
	if ([usage isEqualToString: GlkFileUsageData])
		return [NSArray arrayWithObjects: @"dat", nil];
	else if ([usage isEqualToString: GlkFileUsageSavedGame]) 
		return [NSArray arrayWithObjects: @"sav", nil];
	else if ([usage isEqualToString: GlkFileUsageInputRecord]) 
		return [NSArray arrayWithObjects: @"txt", @"rec", nil];
	else if ([usage isEqualToString: GlkFileUsageTranscript]) 
		return [NSArray arrayWithObjects: @"txt", nil];
	else if ([usage isEqualToString: GlkFileUsageGameData]) 
		return [NSArray arrayWithObjects: @"blb", nil];
	else if ([usage isEqualToString: GlkFileUsageGameFile]) 
		return [NSArray arrayWithObjects: @"blb", @"ulx", @"glb", @"gblorb", nil];
	
	// Default: return nothing and allow the client to decide
	return nil;
}

- (void) setFileTypes: (in bycopy NSArray*) extensions
			 forUsage: (in bycopy NSString*) usage {
	[extensionsForUsage setObject: [[[NSArray alloc] initWithArray: extensions copyItems: YES] autorelease]
						   forKey: usage];
}

- (void) promptForFilesForUsage: (in bycopy NSString*) usage
					 forWriting: (BOOL) writing
						handler: (in byref NSObject<GlkFilePrompt>*) handler {
	// Pick a preferred directory
	NSURL* preferredDirectoryURL = nil;
	
	if (delegate && [delegate respondsToSelector: @selector(preferredSaveDirectory)]) {
		preferredDirectoryURL = [NSURL fileURLWithPath: [delegate preferredSaveDirectory]];
	}
	
	if (preferredDirectoryURL == nil) {
		preferredDirectoryURL = [NSURL URLWithString: [[NSUserDefaults standardUserDefaults] objectForKey: @"GlkSaveDirectoryURL"]];
	}
	
	// Defer to the delegate if it has the appropriate method implemented
	if (delegate && [delegate respondsToSelector: @selector(promptForFilesForUsage:forWriting:handler:preferredDirectory:)]) {
		if ([delegate promptForFilesForUsage: usage
								  forWriting: writing
									 handler: handler
						  preferredDirectory: [preferredDirectoryURL path]]) {
			// The delegate is handling this event
			return;
		}
	}
	
	// Use the standard prompting mechanism
	[self promptForFilesOfType: [self fileTypesForUsage: usage]
					forWriting: writing
					   handler: handler];
}

- (void) promptForFilesOfType: (in bycopy NSArray*) filetypes
				   forWriting: (BOOL) writing
					  handler: (in byref NSObject<GlkFilePrompt>*) handler {
	// If we don't have a window, we can't show a dialog, so we can't get a filename
	if (![self window]) {
		[handler promptCancelled];
		return;
	}
	
	if ([filetypes count] <= 0) {
		NSLog(@"Can't prompt for files: no filetypes requested");
		[handler promptCancelled];
		return;
	}
	
	// Pick a preferred directory
	NSURL* preferredDirectoryURL = nil;
	
	if (delegate && [delegate respondsToSelector: @selector(preferredSaveDirectory)]) {
		preferredDirectoryURL = [NSURL fileURLWithPath:[delegate preferredSaveDirectory]];
	}
	
	if (preferredDirectoryURL == nil) {
		preferredDirectoryURL = [NSURL URLWithString: [[NSUserDefaults standardUserDefaults] objectForKey: @"GlkSaveDirectoryURL"]];
	}
	
	// Cache the handler
	[promptHandler release];
	promptHandler = [handler retain];
	
	// Cache the allowed file types
	[allowedFiletypes release];
	allowedFiletypes = [filetypes copy];
	
	// Work out whether or not to show a sheet
	NSWindow* window = [self window];
	
	BOOL showAsSheet = YES;
	if (([window styleMask]) == NSBorderlessWindowMask) showAsSheet = NO;
	
	// Create the prompt
	if (writing) {
		// Create a save dialog
		NSSavePanel* panel = [NSSavePanel savePanel];
		
		if (preferredDirectoryURL != nil) {
            [panel setDirectoryURL: preferredDirectoryURL];
        }
		
        [panel setAllowedFileTypes: allowedFiletypes];
		
        [panel beginSheetModalForWindow: showAsSheet ? window : nil
                      completionHandler:^(NSInteger returnCode)
         {
             if (promptHandler) {
                 if (returnCode == NSOKButton) {
                     GlkFileRef* promptRef = [[GlkFileRef alloc] initWithPath: [[panel URL] path]];
                     [promptHandler promptedFileRef: promptRef];
                     [promptRef autorelease];
                     
                     [[NSUserDefaults standardUserDefaults] setObject: [[panel directoryURL] absoluteString]
                                                               forKey: @"GlkSaveDirectoryURL"];
                     if( [[panel directoryURL] path] != nil ) {
                         if (delegate && [delegate respondsToSelector: @selector(savePreferredDirectory:)]) {
                             [delegate savePreferredDirectory: [[panel directoryURL] path]];
                         }
                     }
                 } else {
                     [promptHandler promptCancelled];
                 }
                 
                 [promptHandler release]; promptHandler = nil;
                 [allowedFiletypes release]; allowedFiletypes = nil;
                 [lastPanel release]; lastPanel = nil;
             }
         }];
		
		[lastPanel release]; lastPanel = [panel retain];
	} else {
		// Create an open dialog
		NSOpenPanel* panel = [NSOpenPanel openPanel];

		if (preferredDirectoryURL != nil) {
            [panel setDirectoryURL: preferredDirectoryURL];
        }

        [panel setAllowedFileTypes: allowedFiletypes];

        [panel beginSheetModalForWindow: showAsSheet ? window : nil
                      completionHandler:^(NSInteger returnCode)
         {
             if (promptHandler) {
                 if (returnCode == NSOKButton) {
                     GlkFileRef* promptRef = [[GlkFileRef alloc] initWithPath: [[panel URL] path]];
                     [promptHandler promptedFileRef: promptRef];
                     [promptRef autorelease];
                     
                     [[NSUserDefaults standardUserDefaults] setObject: [[panel directoryURL] absoluteString]
                                                               forKey: @"GlkSaveDirectoryURL"];
                     if( [[panel directoryURL] path] != nil ) {
                         if (delegate && [delegate respondsToSelector: @selector(savePreferredDirectory:)]) {
                             [delegate savePreferredDirectory: [[panel directoryURL] path]];
                         }
                     }
                 } else {
                     [promptHandler promptCancelled];
                 }
                 
                 [promptHandler release]; promptHandler = nil;
                 [allowedFiletypes release]; allowedFiletypes = nil;
                 [lastPanel release]; lastPanel = nil;
             }
         }];
		
		[lastPanel release]; lastPanel = [panel retain];
	}
}

- (void) panelDidEnd: (NSSavePanel*) panel
		  returnCode: (int) returnCode
		 contextInfo: (void*) willBeNil {
	if (!promptHandler) return;
	
	if (returnCode == NSOKButton) {
		GlkFileRef* promptRef = [[GlkFileRef alloc] initWithPath: [[panel URL] path]];
		[promptHandler promptedFileRef: promptRef];
		[promptRef autorelease];
		
		[[NSUserDefaults standardUserDefaults] setObject: [[panel directoryURL] absoluteString]
												  forKey: @"GlkSaveDirectoryURL"];
		if (delegate && [delegate respondsToSelector: @selector(savePreferredDirectory:)]) {
			[delegate savePreferredDirectory: [[panel directoryURL] path]];
		}
	} else {
		[promptHandler promptCancelled];
	}
	
	[promptHandler release]; promptHandler = nil;
	[allowedFiletypes release]; allowedFiletypes = nil;
	[lastPanel release]; lastPanel = nil;
}


// = Dealing with buffer operations =

// Creating the various types of window

// Note that creating a new window doesn not always mean that we need to change the layout (as the windows don't actually
// exist in the tree until the appropriate pair window is created)

- (void) createBlankWindowWithIdentifier: (glui32) identifier {
	GlkWindow* newWindow = [[GlkWindow alloc] init];
	
	[newWindow setIdentifier: identifier];
	[newWindow setEventTarget: self];
	[newWindow setPreferences: prefs];
	[newWindow setContainingView: self];
	
	[glkWindows setObject: [newWindow autorelease]
				   forKey: [NSNumber numberWithUnsignedInt: identifier]];
}

- (void) createTextGridWindowWithIdentifier: (glui32) identifier {
	GlkWindow* newWindow = [[GlkTextGridWindow alloc] init];
	
	if (scaleFactor != 1.0f) [newWindow setScaleFactor: scaleFactor];
	[newWindow setIdentifier: identifier];
	[newWindow setEventTarget: self];
	[newWindow setStyles: [self stylesForWindowType: wintype_TextGrid]];
	[newWindow setPreferences: prefs];
	[newWindow setContainingView: self];
	
	[glkWindows setObject: [newWindow autorelease]
				   forKey: [NSNumber numberWithUnsignedInt: identifier]];
}

- (void) createTextWindowWithIdentifier: (glui32) identifier {
	GlkWindow* newWindow = [[GlkTextWindow alloc] init];
	
	if (scaleFactor != 1.0f) [newWindow setScaleFactor: scaleFactor];
	[newWindow setIdentifier: identifier];
	[newWindow setEventTarget: self];
	[newWindow setStyles: [self stylesForWindowType: wintype_TextBuffer]];
	[newWindow setPreferences: prefs];
	[newWindow setContainingView: self];
	
	[glkWindows setObject: [newWindow autorelease]
				   forKey: [NSNumber numberWithUnsignedInt: identifier]];
}

- (void) createGraphicsWindowWithIdentifier: (glui32) identifier {
	GlkWindow* newWindow = [[GlkGraphicsWindow alloc] init];
	
	if (scaleFactor != 1.0f) [newWindow setScaleFactor: scaleFactor];
	[newWindow setIdentifier: identifier];
	[newWindow setEventTarget: self];
	[newWindow setStyles: [self stylesForWindowType: wintype_Graphics]];
	[newWindow setPreferences: prefs];
	[newWindow setContainingView: self];
	
	[glkWindows setObject: [newWindow autorelease]
				   forKey: [NSNumber numberWithUnsignedInt: identifier]];
}

// Placing windows in the tree

- (int) automationIdForWindowId: (glui32) identifier {
	if (windowPositionCache == nil) {
		// Initialise the caches
		[windowPositionCache release];
		[windowIdCache release];
		windowPositionCache = [[NSMutableDictionary alloc] init];
		windowIdCache = [[NSMutableDictionary alloc] init];
		
		// Fill the position cache
		int position = 0;
		
		GlkWindow* currentWindow = rootWindow;
		NSMutableArray* positionStack = [NSMutableArray array];
		
		while (currentWindow != nil || [positionStack count] > 0) {
			// If there's no current window, then pop one from the stack
			if (currentWindow == nil) {
				currentWindow = [positionStack lastObject];
				[positionStack removeLastObject];
			}
			
			// Associate this window with its identifier
			[windowPositionCache setObject: [NSNumber numberWithInt: position]
									forKey: [NSNumber numberWithUnsignedInt: [currentWindow identifier]]];
			[windowIdCache setObject: currentWindow
							  forKey: [NSNumber numberWithInt: position]];
			
			// Move to the next window
			GlkWindow* left = nil;
			GlkWindow* right = nil;
			if ([currentWindow isKindOfClass: [GlkPairWindow class]]) {
				left = [(GlkPairWindow*)currentWindow leftWindow];
				right = [(GlkPairWindow*)currentWindow rightWindow];
			}
			
			currentWindow = left;
			if (right != nil) [positionStack addObject: right];
				
			// Set the next position
			position++;
		}
	}
	
	// Get the cached position
	NSNumber* position = [windowPositionCache objectForKey: [NSNumber numberWithUnsignedInt: identifier]];
	
	// Return the result
	if (position == nil) return -1;
	return [position intValue];
}

- (GlkWindow*) glkWindowForAutomationId: (int) autoId {
	if (windowIdCache == nil) {
		// A side-effect of this call is that the caches are filled
		[self automationIdForWindowId: 0];
	}
	
	return [windowIdCache objectForKey: [NSNumber numberWithInt: autoId]];
}

- (void) setRootWindow: (glui32) identifier {
	if (identifier == GlkNoWindow) {
		[rootWindow release];
		rootWindow = nil;
		
		windowsNeedLayout = YES;
		return;
	}
	
	GlkWindow* newRootWindow = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: identifier]];
	
	[windowPositionCache release];
	[windowIdCache release];
	windowPositionCache = nil;
	windowIdCache = nil;
	
	if (newRootWindow) {
		if (rootWindow == nil) [self showLogoWindow];
		
		[rootWindow release];
		rootWindow = [newRootWindow retain];
		
		[rootWindow setScaleFactor: scaleFactor];
		
		windowsNeedLayout = YES;
	} else {
		NSLog(@"Warning: attempt to set the root window to a nonexistent window");
	}
}

- (void) createPairWindowWithIdentifier: (glui32) identifier
							  keyWindow: (glui32) keyId
							 leftWindow: (glui32) leftId
							rightWindow: (glui32) rightId
								 method: (glui32) method
								   size: (glui32) size {
	GlkWindow* key = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: keyId]];
	GlkWindow* left = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: leftId]];
	GlkWindow* right = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: rightId]];
	
	// Sanity check
	if (key == nil || left == nil || right == nil) {
		NSLog(@"Warning: attempt to create pair window with nonexistent child windows");
		return;
	}
	
	if ([right parent] != nil) {
		NSLog(@"Warning: rightmost window of a pair must not already be in the tree (odd behaviour will result)");
	}
	
	// Flush the automation cache
	[windowPositionCache release];
	[windowIdCache release];
	windowPositionCache = nil;
	windowIdCache = nil;
	
	// Create the pair window
	GlkPairWindow* newWin = [[GlkPairWindow alloc] init];
	glui32 winDir = method & winmethod_DirMask;
	
	if (scaleFactor != 1.0f) [newWin setScaleFactor: scaleFactor];
	[newWin setBorderWidth: borderWidth];
	[newWin setFixed: (method&winmethod_Fixed)!=0];
	[newWin setSize: size];
	[newWin setAbove: winDir==winmethod_Above||winDir==winmethod_Left];
	[newWin setHorizontal: winDir==winmethod_Left||winDir==winmethod_Right];
	[newWin setIdentifier: identifier];
	[newWin setEventTarget: self];
	[newWin setPreferences: prefs];
	[newWin setContainingView: self];
	
	// Change the structure if the left window is not topmost
	if ([left parent]) {
		if ([[left parent] leftWindow] == left) {
			[[left parent] setLeftWindow: newWin];
		} else if ([[left parent] rightWindow] == left) {
			[[left parent] setRightWindow: newWin];
		} else {
			NSLog(@"Warning: parent windows do not match up (odd behaviour will result)");
		}
	}
	
	// Set the structure of the new window
	[newWin setKeyWindow: key];
	[newWin setLeftWindow: left];
	[newWin setRightWindow: right];

	[right setParent: newWin];
	[left setParent: newWin];
	
	// Add to the window structure
	[glkWindows setObject: [newWin autorelease]
				   forKey: [NSNumber numberWithUnsignedInt: identifier]];
	windowsNeedLayout = YES;
}

// Manipulating windows

- (void) moveCursorInWindow: (glui32) identifier
				toXposition: (int) xpos
				  yPosition: (int) ypos {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: identifier]];
	
	if (!win) {
		NSLog(@"Warning: attempt to move cursor in nonexistent window");
		return;
	}
	
	[win moveCursorToXposition: xpos
					 yPosition: ypos];
}

- (void) clearWindowIdentifier: (glui32) identifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: identifier]];
	
	if (!win) {
		NSLog(@"Warning: attempt to clear nonexistent window");
		return;
	}
	
	[win clearWindow];
}

- (void) clearWindowIdentifier: (glui32) identifier 
		  withBackgroundColour: (in bycopy NSColor*) bgCol {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: identifier]];
	
	if (!win) {
		NSLog(@"Warning: attempt to clear nonexistent window");
		return;
	}
	
	if ([win isKindOfClass: [GlkGraphicsWindow class]]) {
		[(GlkGraphicsWindow*)win setBackgroundColour: bgCol];
	}
	
	[win clearWindow];
}

- (void) setInputLine: (in bycopy NSString*) inputLine
  forWindowIdentifier: (unsigned) identifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: identifier]];
	
	if (!win) {
		NSLog(@"Warning: attempt to set input line for nonexistent window");
		return;
	}
	
	[win setInputLine: [NSString stringWithString: inputLine]];
}

- (void) arrangeWindow: (glui32) identifier
				method: (glui32) method
				  size: (glui32) size
			 keyWindow: (glui32) keyIdentifier {
	GlkPairWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: identifier]];
	GlkWindow* keyWin = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: keyIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: attempt to arrange a nonexistent window");
		return;
	}
	
	if (!keyWin && keyIdentifier != GlkNoWindow) {
		NSLog(@"Warning: attempt to arrange with a nonexistent key window");
		return;
	}
	
	if (![win isKindOfClass: [GlkPairWindow class]]) {
		NSLog(@"Warning: attempt to arrange a non-pair window");
		return;
	}

	glui32 winDir = method & winmethod_DirMask;

	[win setKeyWindow: keyWin];
	[win setFixed: (method&winmethod_Fixed)!=0];
	[win setSize: size];
	[win setAbove: winDir==winmethod_Above||winDir==winmethod_Left];
	[win setHorizontal: winDir==winmethod_Left||winDir==winmethod_Right];
	
	windowsNeedLayout = YES;
}

// Styles

- (void) setStyleHint: (glui32) hint
			 forStyle: (glui32) styl
			  toValue: (glsi32) value
		   windowType: (glui32) wintype {
	if (wintype == wintype_AllTypes) {
		// Deal with setting styles on win_AllTypes
		[self setStyleHint: hint
				  forStyle: styl
				   toValue: value
				windowType: wintype_TextBuffer];
		[self setStyleHint: hint
				  forStyle: styl
				   toValue: value
				windowType: wintype_TextGrid];
		[self setStyleHint: hint
				  forStyle: styl
				   toValue: value
				windowType: wintype_Graphics];
		return;
	}
	
	// Get the information for this style
	NSMutableDictionary* winStyles = [self stylesForWindowType: wintype];
	NSNumber* styleNumber = [NSNumber numberWithUnsignedInt: styl];
	GlkStyle* style = [winStyles objectForKey: styleNumber];
	
	if (style == nil) {
		// Create a style if one doesn't already exist for this style number
		style = [GlkStyle style];
		
		[winStyles setObject: style
					  forKey: styleNumber];
	}
	
	// Set the flags appropriate for the hint
	[style setHint: hint
		   toValue: value];
}

- (void) clearStyleHint: (glui32) hint
			   forStyle: (glui32) styl
			 windowType: (glui32) wintype {
	if (wintype == wintype_AllTypes) {
		// Deal with setting styles on win_AllTypes
		[self clearStyleHint: hint
					forStyle: styl
				  windowType: wintype_TextBuffer];
		[self clearStyleHint: hint
				  forStyle: styl
				windowType: wintype_TextGrid];
		[self clearStyleHint: hint
					forStyle: styl
				  windowType: wintype_Graphics];
		return;
	}
	
	// Get the information for this style
	NSMutableDictionary* winStyles = [self stylesForWindowType: wintype];
	NSNumber* styleNumber = [NSNumber numberWithUnsignedInt: styl];
	GlkStyle* style = [winStyles objectForKey: styleNumber];
	
	if (style == nil) {
		// Nothing to do
		return;
	}

	// Get the default setting for this style
	GlkStyle* defaultStyle = [[prefs styles] objectForKey: styleNumber];
	if (!defaultStyle) defaultStyle = [GlkStyle style];
	
	// Set the flags appropriate for the hint
	[style setHint: hint
	  toMatchStyle: defaultStyle];
}

- (void) setStyleHint: (glui32) hint
			  toValue: (glsi32) value
			 inStream: (glui32) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (!stream) {
		NSLog(@"Warning: attempt to set an immediate style hint in an undefined stream");
		return;
	}
	
	[stream setImmediateStyleHint: hint
						  toValue: value];
}

- (void) clearStyleHint: (glui32) hint
			   inStream: (glui32) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (!stream) {
		NSLog(@"Warning: attempt to clear an immediate style hint in an undefined stream");
		return;
	}
	
	[stream clearImmediateStyleHint: hint];	
}

- (void) setCustomAttributes: (NSDictionary*) attributes
					inStream: (glui32) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (!stream) {
		NSLog(@"Warning: attempt to set custom attributes in an undefined stream");
		return;
	}

	[stream setCustomAttributes: attributes];
}

// Closing windows

- (void) removeIdentifier: (glui32) identifier {
	GlkPairWindow* win = [[glkWindows objectForKey: [NSNumber numberWithUnsignedInt: identifier]] retain];

	if ([win isKindOfClass: [GlkPairWindow class]]) {
		// Remove the ID for the left and right windows
		if ([win leftWindow]) [self removeIdentifier: [[win leftWindow] identifier]];
		if ([win rightWindow]) [self removeIdentifier: [[win rightWindow] identifier]];
	}
	
	// Remove from the list of known windows
	[glkWindows removeObjectForKey: [NSNumber numberWithUnsignedInt: identifier]];
	
	// Remove from the superview
	[win removeFromSuperviewWithoutNeedingDisplay];
	
	// Remove from existence (usually)
	[win release];
	
	windowsNeedLayout = YES;
}

- (void) closeWindowIdentifier: (glui32) identifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: identifier]];
	
	if (!win) {
		NSLog(@"Warning: attempt to close a nonexistent window");
		return;
	}
	
	// Deal with the parent window
	GlkPairWindow* parent = [win parent];
	
	if (parent) {
		GlkPairWindow* grandparent = [parent parent];
		GlkWindow* sibling = nil;
		
		// Find our sibling
		if ([parent leftWindow] == win) {
			sibling = [[[parent rightWindow] retain] autorelease];
			[parent setRightWindow: nil];
		} else if ([parent rightWindow] == win) {
			sibling = [[[parent leftWindow] retain] autorelease];
			[parent setLeftWindow: nil];
		} else {
			NSLog(@"Oops, failed to find a sibling window");
		}
		
		[parent setParent: nil];
		
		if (grandparent) {
			// Replace the appropriate window in the grandparent
			[sibling setParent: grandparent];
			
			if ([grandparent leftWindow] == parent) {
				[grandparent setLeftWindow: sibling];
			} else if ([grandparent rightWindow] == parent) {
				[grandparent setRightWindow: sibling];
			} else {
				NSLog(@"Oops, failed to find the parent window in the grandparent");
			}
		} else {
			// Replace the root window
			[rootWindow release];
			rootWindow = [sibling retain];
		}
		
		// Mark the parent as closed
		[parent setClosed: YES];
		
		// Remove the parent window identifier
		[self removeIdentifier: [parent identifier]];
	} else {
		// We've closed the root window
		[rootWindow release];
		rootWindow = nil;
		
		// Mark this window as closed
		[win setClosed: YES];
		
		// Remove this window identifier
		[self removeIdentifier: identifier];
	}
	
	// We'll need to layout the windows again
	windowsNeedLayout = YES;
}

// Streams

// Registering streams

- (void) registerStream: (in byref NSObject<GlkStream>*) stream
		  forIdentifier: (unsigned) streamIdentifier {
	[glkStreams setObject: stream
				   forKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
}

- (void) registerStreamForWindow: (unsigned) windowIdentifier
				   forIdentifier: (unsigned) streamIdentifier {
	GlkWindow* window = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];

	if (window == nil) {
		NSLog(@"Warning: attempt to register stream for nonexistent window");
		return;
	}
	
	[self registerStream: window
		   forIdentifier: streamIdentifier];
}

- (void) closeStreamIdentifier: (unsigned) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (!stream) {
		NSLog(@"Warning: attempt to close nonexistent stream");
		return;
	}
	
	[stream closeStream];
	[glkStreams removeObjectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
}

- (void) unregisterStreamIdentifier: (unsigned) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (!stream) {
		// Stream might not have been registered to begin with: we consider this OK
		return;
	}
	
	[glkStreams removeObjectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
}

// Buffering stream writes

- (void) automateStream: (NSObject<GlkStream>*) stream
			  forString: (NSString*) string {
	// If this is a text window stream, then send the output to the appropriate automation objects
	if ([stream isKindOfClass: [GlkTextWindow class]] &&
		![stream isKindOfClass: [GlkTextGridWindow class]]) {
		NSEnumerator* outputEnum = [outputReceivers objectEnumerator];
		NSObject<GlkAutomation>* receiver;
		
		int windowId = [self automationIdForWindowId: [(GlkTextWindow*)stream identifier]];
		
		while (receiver = [outputEnum nextObject]) {
			[receiver receivedCharacters: string
								  window: windowId
								fromView: self];
		}
	}
}

- (void) putChar: (unichar) ch
		toStream: (unsigned) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (stream == nil) {
		NSLog(@"Warning: attempt to write to nonexistent stream");
		return;
	}
	
	if ([outputReceivers count] > 0) {
		unichar c[1] = { ch };
		[self automateStream: stream
				   forString: [NSString stringWithCharacters: c
													  length: 1]];
	}
	
	[stream putChar: ch];
}

- (void) putString: (in bycopy NSString*) string
		  toStream: (unsigned) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (stream == nil) {
		NSLog(@"Warning: attempt to write to nonexistent stream");
		return;
	}

	if ([outputReceivers count] > 0) {
		[self automateStream: stream
				   forString: string];
	}
	
	[stream putString: [NSString stringWithString: string]];
}

- (void) putData: (in bycopy NSData*) data
		toStream: (unsigned) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (stream == nil) {
		NSLog(@"Warning: attempt to write to nonexistent stream");
		return;
	}
	
	[stream putBuffer: data];
}

- (void) setStyle: (unsigned) style
		 onStream: (unsigned) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (stream == nil) {
		NSLog(@"Warning: attempt to set style on a nonexistent stream");
		return;
	}
	
	[stream setStyle: style];
}


// = Hyperlinks on streams =

- (void) setHyperlink: (unsigned int) value
			 onStream: (unsigned) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (stream == nil) {
		NSLog(@"Warning: attempt to set style on a nonexistent stream");
		return;
	}
	
	[stream setHyperlink: value];
}

- (void) clearHyperlinkOnStream: (unsigned) streamIdentifier {
	NSObject<GlkStream>* stream = [glkStreams objectForKey: [NSNumber numberWithUnsignedInt: streamIdentifier]];
	
	if (stream == nil) {
		NSLog(@"Warning: attempt to set style on a nonexistent stream");
		return;
	}
	
	[stream clearHyperlink];
}

// = Requesting events =

- (GlkWindow*) suggestedFirstResponder: (GlkWindow*) win {
	if ([win waitingForKeyboardInput]) {
		return win;
	} else if ([win isKindOfClass: [GlkPairWindow class]]) {
		GlkWindow* left = [self suggestedFirstResponder: [(GlkPairWindow*)win leftWindow]];
		GlkWindow* right = [self suggestedFirstResponder: [(GlkPairWindow*)win rightWindow]];
		
		// If only one of left or right has a suggestion, then the result is that
		if (!left && !right) return nil;
		if (left && !right) return left;
		if (right && !left) return right;
		
		// We prefer line input windows to character input, and text windows to text grids
		if ([left waitingForLineInput]) return left;
		if ([right waitingForLineInput]) return right;
		
		if ([left isKindOfClass: [GlkTextWindow class]]) return left;
		if ([right isKindOfClass: [GlkTextWindow class]]) return right;
		return left;
	} else {
		return nil;
	}
}

- (BOOL) findFirstResponder: (GlkWindow*) win {
	GlkWindow* newWin = [self suggestedFirstResponder: win];
	if (newWin != nil) {
		[[self window] makeFirstResponder: [newWin windowResponder]];
		NSAccessibilityPostNotification(newWin, NSAccessibilityFocusedUIElementChangedNotification);
		return YES;
	} else {
		return NO;
	}
}

- (BOOL) setFirstResponder {
	NSResponder* lastFirstResponder = [[self window] firstResponder];
	NSView* lastWindowResponder = nil;
	
	if ([lastFirstResponder isKindOfClass: [NSView class]]) {
		lastWindowResponder = (NSView*) lastFirstResponder;
		
		while (lastWindowResponder != nil && ![lastWindowResponder isKindOfClass: [GlkWindow class]]) {
			lastWindowResponder = [lastWindowResponder superview];
		}
	}
	
	// Choose a new first responder if the current first responder is the window, or there's no first responder, or the first responder is a GlkWindow and isn't waiting for any input
	if (lastFirstResponder == nil || 
		(lastWindowResponder != nil && ![(GlkWindow*)lastWindowResponder waitingForKeyboardInput]) ||
		([lastFirstResponder isKindOfClass: [NSView class]] && ([(NSView*)lastFirstResponder superview] == nil || ![(NSView*)lastFirstResponder acceptsFirstResponder])) ||
		[lastFirstResponder isKindOfClass: [NSWindow class]] ||
		([lastFirstResponder isKindOfClass: [GlkWindow class]] && ![(GlkWindow*)lastFirstResponder waitingForKeyboardInput])) {
		// Pick a new first responder
		return [self findFirstResponder: rootWindow];
	}
	
	return NO;
}

- (void) requestLineEventsForWindowIdentifier: (unsigned) windowIdentifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: events requested for a window that does not exist");
		return;
	}
	
	[win requestLineInput];
}

- (void) requestCharEventsForWindowIdentifier: (unsigned) windowIdentifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: events requested for a window that does not exist");
		return;
	}
	
	[win requestCharInput];
}

- (void) requestMouseEventsForWindowIdentifier: (unsigned) windowIdentifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: events requested for a window that does not exist");
		return;
	}
	
	[win requestMouseInput];
}

- (void) requestHyperlinkEventsForWindowIdentifier: (unsigned) windowIdentifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: events requested for a window that does not exist");
		return;
	}
	
	[win requestHyperlinkInput];
}

- (bycopy NSString*) cancelLineEventsForWindowIdentifier: (unsigned) windowIdentifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: events cancelled for a window that does not exist");
		return @"";
	}
	
	return [win cancelLineInput];
}

- (void) cancelCharEventsForWindowIdentifier: (unsigned) windowIdentifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: events cancelled for a window that does not exist");
		return;
	}
	
	[win cancelCharInput];
}

- (void) cancelMouseEventsForWindowIdentifier: (unsigned) windowIdentifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: events cancelled for a window that does not exist");
		return;
	}
	
	[win cancelMouseInput];
}

- (void) cancelHyperlinkEventsForWindowIdentifier: (unsigned) windowIdentifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: events requested for a window that does not exist");
		return;
	}
	
	[win cancelHyperlinkInput];
}

// = Image management =

- (void) setImageSource: (in byref id<GlkImageSource>) source {
	imgSrc = [(NSObject<GlkImageSource>*)source retain];
}

- (out byref id<GlkImageSource>) imageSource {
	return [[imgSrc retain] autorelease];
}

- (NSImage*) flippedImageWithIdentifier: (unsigned) imageId {
	//
	// This works around a bug in the design of Cocoa: text views are flipped. This causes images to be drawn
	// upside down. You can undo the flipping using an NSAffineTransform; unfortunately because there doesn't
	// seem to be a way to get the current transform (or apply a new transform to it), this also removes
	// information on the containing scroll view. Calling setFlipped: YES on an image fixes this, but only
	// if the call is made before the image is drawn (apparently regardless of the caching status of the image).
	//
	// So, the purpose of this call is to create flipped copies of images that can be used in text views.
	// Yup, this is wasteful of memory, but I'm otherwise out of ideas.
	//
	// ObRant: this is kind of like the text system: it appears to offer a rich API, but which is, in practice,
	// so fragile that making things happen is a matter of trial and error. See also my 'resolution information
	// removal' code in imageWithIdentifier (if you draw a high-res image at a large size, Cocoa reduces the
	// resolution BEFORE rendering. Genius!)
	//
	if (!flippedImageDictionary) flippedImageDictionary = [[NSMutableDictionary alloc] init];
	
	// First, try to retrieve the image from the cache to save us a round-trip
	NSNumber* imageKey = [NSNumber numberWithUnsignedInt: imageId];
	NSImage* image = [flippedImageDictionary objectForKey: imageKey];
	
	if (image) return image;
	
	// Build a flipped image from the non-flipped version
	image = [self imageWithIdentifier: imageId];
	if (!image) return nil;
	
	NSImage* flippedImage = [[[NSImage alloc] initWithSize: [image size]] autorelease];
	NSRect imageRect;
	
	imageRect.origin = NSMakePoint(0,0);
	imageRect.size = [image size];
	
	[flippedImage setFlipped: YES];
	[flippedImage lockFocus];
	[image drawInRect: imageRect
			 fromRect: imageRect
			operation: NSCompositeSourceOver
			 fraction: 1.0];
	[flippedImage unlockFocus];
	
	[flippedImageDictionary setObject: flippedImage
							   forKey: imageKey];
	
	return flippedImage;
}

- (NSImage*) imageWithIdentifier: (unsigned) imageId {
	// First, try to retrieve the image from the cache to save us a round-trip
	NSNumber* imageKey = [NSNumber numberWithUnsignedInt: imageId];
	NSImage* image = [imageDictionary objectForKey: imageKey];
	
	if (image) return image;
	
	// Try to retrieve the image from the client process
	// FIXME: if this fails, we'll keep on trying - probably not a good idea
	// FIXME: limit the number of images in the cache to save on memory (?)
	NSData* imageData = nil;
	
	if (imgSrc) {
		imageData = [imgSrc dataForImageResource: imageId];
	}
	
	// Store the result in the dictionary
	if (imageData) {
		// Get the source image
		NSImage* sourceImage = [[[NSImage alloc] initWithData: imageData] autorelease];
		
		// Turn off caching for this image to stop Cocoa doing something 'clever' which actually turns out to be stupid (pixelates the logo in Narcolepsy)
		[sourceImage setCacheMode: NSImageCacheNever];
		
		// Narcolepsy (for example) uses images with a resolution that might not be the screen resolution.
		// This is annoying. This should re-render the image at a more suitable resolution
		NSImageRep* rep = [[sourceImage representations] objectAtIndex: 0];
		NSSize pixelSize = NSMakeSize([rep pixelsWide], [rep pixelsHigh]);
		NSRect srcRect;
		
		srcRect.origin = NSMakePoint(0,0);
		srcRect.size = [sourceImage size];
		
		image = [[NSImage alloc] initWithSize: pixelSize];
		
		[image lockFocus];
		[sourceImage drawInRect: NSMakeRect(0,0, pixelSize.width, pixelSize.height)
					   fromRect: srcRect
					  operation: NSCompositeSourceOver
					   fraction: 1.0];
		[image unlockFocus];

		// Store in the dictionary
		[imageDictionary setObject: [image autorelease]
							forKey: imageKey];
	}
	
	// Return the result
	return image;
}

// = Graphics functions =

- (NSSize) sizeForImageResource: (glui32) imageId {
	NSImage* img = [self imageWithIdentifier: imageId];
	
	if (img == nil) return NSMakeSize(-1, -1);
	
	return [img size];
}

- (void) fillAreaInWindowWithIdentifier: (unsigned) windowIdentifier
							 withColour: (in bycopy NSColor*) col
							  rectangle: (NSRect) rect {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: fillAreaInWindowWithIdentifier: called for a window that does not exist");
		return;
	}
	
	if (![win isKindOfClass: [GlkGraphicsWindow class]]) {
		NSLog(@"Warning: fillAreaInWindowWithIdentifier: called for a non-graphics window");
		return;
	}
	
	[(GlkGraphicsWindow*)win fillRect: rect
						   withColour: col];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					  atPosition: (NSPoint) position {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: drawImageInWindowWithIdentifier:atPosition: called for a window that does not exist");
		return;
	}
	
	if (![win isKindOfClass: [GlkGraphicsWindow class]]) {
		NSLog(@"Warning: drawImageInWindowWithIdentifier:atPosition: called for a non-graphics window");
		return;
	}
	
	NSImage* img = [self imageWithIdentifier: imageIdentifier];
	
	if (!img) {
		NSLog(@"Warning: drawImageInWindowWithIdentifier:atPosition: called for an image that does not exist");
		return;
	}
	
	NSRect imgRect;
	
	imgRect.origin = position;
	imgRect.size = [img size];
		
	[(GlkGraphicsWindow*)win drawImage: img
								inRect: imgRect];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
						  inRect: (NSRect) imageRect {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];

	if (!win) {
		NSLog(@"Warning: drawImageInWindowWithIdentifier:inRect: called for a window that does not exist");
		return;
	}
	
	if (![win isKindOfClass: [GlkGraphicsWindow class]]) {
		NSLog(@"Warning: drawImageInWindowWithIdentifier:inRect: called for a non-graphics window");
		return;
	}
	
	NSImage* img = [self imageWithIdentifier: imageIdentifier];
	
	if (!img) {
		NSLog(@"Warning: drawImageInWindowWithIdentifier:inRect: called for an image that does not exist");
		return;
	}

	[(GlkGraphicsWindow*)win drawImage: img
								inRect: imageRect];
}


- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment {
	[self drawImageWithIdentifier: imageIdentifier
		   inWindowWithIdentifier: windowIdentifier
						alignment: alignment
							 size: [self sizeForImageResource: imageIdentifier]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment
							size: (NSSize) imageSize {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: drawImageInWindowWithIdentifier: called for a window that does not exist");
		return;
	}
	
	if (![win isKindOfClass: [GlkTextWindow class]]) {
		NSLog(@"Warning: drawImageInWindowWithIdentifier: called for a non-graphics window");
		return;
	}
	
	NSImage* img = [self flippedImageWithIdentifier: imageIdentifier];
	
	if (!img) {
		NSLog(@"Warning: drawImageInWindowWithIdentifier: called for an image that does not exist");
		return;
	}
	
	[(GlkTextWindow*)win addImage: img
					withAlignment: alignment
							 size: imageSize];
}

- (void) breakFlowInWindowWithIdentifier: (unsigned) windowIdentifier {
	GlkWindow* win = [glkWindows objectForKey: [NSNumber numberWithUnsignedInt: windowIdentifier]];
	
	if (!win) {
		NSLog(@"Warning: breakFlowInWindowWithIdentifier: called for a window that does not exist");
		return;
	}
	
	if (![win isKindOfClass: [GlkTextWindow class]]) {
		NSLog(@"Warning: breakFlowInWindowWithIdentifier: called for a non-text window");
		return;
	}
	
	// Break the flow
	[(GlkTextWindow*)win addFlowBreak];
}

// = Dealing with line history =

- (void) addHistoryItem: (NSString*) inputLine 
		forWindowWithId: (glui32) windowId {
	[inputHistory addObject: inputLine];
	
	if ([outputReceivers count] > 0) {
		NSEnumerator* outputReceiverEnum = [outputReceivers objectEnumerator];
		NSObject<GlkAutomation>* receiver;
		int ident = [self automationIdForWindowId: windowId];
		
		while (receiver = [outputReceiverEnum nextObject]) {
			[receiver userTyped: inputLine
						 window: ident
					  lineInput: YES
					   fromView: self];				
		}
	}
}

- (NSString*) previousHistoryItem {
	if ([inputHistory count] <= 0) return nil;
	
	historyPosition--;
	if (historyPosition < 0) historyPosition = [inputHistory count]-1;
	
	return [inputHistory objectAtIndex: historyPosition];
}

- (NSString*) nextHistoryItem {
	if ([inputHistory count] <= 0) return nil;
	
	historyPosition++;
	if (historyPosition >= [inputHistory count]) historyPosition = 0;
	
	return [inputHistory objectAtIndex: historyPosition];
}

- (void) resetHistoryPosition {
	historyPosition = -1;
}

// = Automation =

- (void) addOutputReceiver: (NSObject<GlkAutomation>*) receiver {
	[outputReceivers addObject: receiver];
}

- (void) addInputReceiver: (NSObject<GlkAutomation>*) receiver {
	[inputReceivers addObject: receiver];
}

- (void) removeAutomationObject: (NSObject<GlkAutomation>*) receiver {
	[outputReceivers removeObjectIdenticalTo: receiver];
	[inputReceivers removeObjectIdenticalTo: receiver];
}

- (GlkWindow*) rotateFrom: (GlkWindow*) oldWindow {
	// Move to the left if this is a pair window
	if ([oldWindow isKindOfClass: [GlkPairWindow class]]) {
		return [(GlkPairWindow*)oldWindow leftWindow];
	}
	
	// Otherwise, rotate via the parent window (return the right window, if we haven't visited it already)
	GlkWindow* child = oldWindow;
	GlkPairWindow* parent = [oldWindow parent];
	while (parent != nil && [parent rightWindow] == child) {
		child = parent;
		parent = [parent parent];
	}
	
	if (parent != nil) {
		return [parent rightWindow];
	} else {
		// If we've reached the start again, return the root window
		return rootWindow;
	}
}

- (BOOL) canSendInput {
	GlkWindow* candidate = rootWindow;
	GlkWindow* initialCandidate = candidate;
	
	if (![candidate waitingForUserKeyboardInput]) candidate = [self rotateFrom: candidate];
	while (candidate != initialCandidate && candidate != nil && ![candidate waitingForUserKeyboardInput]) {
		candidate = [self rotateFrom: candidate];
	}
	
	return [candidate waitingForUserKeyboardInput];
}

- (int) sendCharacters: (NSString*) characters
			  toWindow: (int) window {
	// Get the initial candidate window
	GlkWindow* candidate = [self glkWindowForAutomationId: window];
	if (candidate == nil) candidate = rootWindow;
	if (candidate == nil) return 0;
	
	// Rotate around until we find a window that is waiting for line or character input
	GlkWindow* initialCandidate = candidate;
	
	if (![candidate waitingForUserKeyboardInput]) candidate = [self rotateFrom: candidate];
	while (candidate != initialCandidate && candidate != nil && ![candidate waitingForUserKeyboardInput]) {
		candidate = [self rotateFrom: candidate];
	}
	
	// If it's waiting for input, then send it some
	if ([candidate waitingForUserKeyboardInput]) {
		[candidate forceLineInput: characters];
	}
	
	return [self automationIdForWindowId: [candidate identifier]];
}

- (int) sendClickAtX: (int) xpos
				   Y: (int) ypos
			toWindow: (int) window {
	return window;
}

// = Writing log messages =

- (void) logMessage: (in bycopy NSString*) message {
	[self logMessage: message
		  withStatus: GlkLogCustom];
}

- (void) logMessage: (in bycopy NSString*) message
	   withPriority: (int) priority {
	[self logMessage: message
		  withStatus: priority==0?GlkLogRoutine:priority==1?GlkLogInformation:GlkLogCustom];
}

- (void) logMessage: (NSString*) message
		 withStatus: (GlkLogStatus) status {
	if (delegate && [delegate respondsToSelector: @selector(showLogMessage:withStatus:)]) {
		[delegate showLogMessage: message
					  withStatus: status];
	}
}

// = More prompts =

static BOOL promptsPendingFrom(GlkWindow* win) {
	if (win == nil) return NO;
	if ([win needsPaging]) return YES;
	
	if ([win isKindOfClass: [GlkPairWindow class]]) {
		if (promptsPendingFrom([(GlkPairWindow*)win leftWindow])) return YES;
		if (promptsPendingFrom([(GlkPairWindow*)win rightWindow])) return YES;
	}
	
	return NO;
}

static BOOL pageAllFrom(GlkWindow* win) {
	BOOL result = NO;
	
	if (win == nil) return NO;
	if ([win needsPaging]) {
		[win page];
		result = YES;
	}
	
	if ([win isKindOfClass: [GlkPairWindow class]]) {
		if (pageAllFrom([(GlkPairWindow*)win leftWindow])) result = YES;
		if (pageAllFrom([(GlkPairWindow*)win rightWindow])) result = YES;
	}
	
	return result;
}

- (BOOL) morePromptsPending {
	return promptsPendingFrom(rootWindow);
}

- (BOOL) pageAll {
	return pageAllFrom(rootWindow);
}

- (void) setAlwaysPageOnMore: (BOOL) alwaysPage {
	alwaysPageOnMore = alwaysPage;
}

- (BOOL) alwaysPageOnMore {
	return alwaysPageOnMore;
}

// Various UI events

- (void) performTabFrom: (GlkWindow*) window
				forward: (BOOL) forward
			keepLooking: (BOOL) keepLooking {
	GlkPairWindow* parent = [window parent];
	GlkWindow* last = window;
	GlkWindow* choice = nil;
	
	while (parent != nil) {
		// Pick the windows that we're choosing between
		GlkWindow* left;
		GlkWindow* right;
		
		if (forward) {
			left = [parent keyWindow];
			right = [parent nonKeyWindow];
		} else {
			left = [parent nonKeyWindow];
			right = [parent keyWindow];
		}
		
		// Pick the next window to visit (try to move to the right)
		GlkWindow* next = nil;
		
		if (last == left) {
			next = right;
		} else {
			next = [parent parent];
		}
		
		if ([next isKindOfClass: [GlkPairWindow class]]) {
			// If the next window is a pair window, then keep searching
			last = parent;
			parent = (GlkPairWindow*) next;
		} else {
			// Otherwise, we've found a new window
			if ([next waitingForKeyboardInput]) {
				// If it's waiting for keyboard input, then it's our choice
				choice = next;
				break;				
			} else {
				// If it's not, then keep looking
				last = next;
				parent = [next parent];
			}
		}
	}
	
	// If choice is nil, we fell off the end of the list of windows
	BOOL startingFromLeftMost = NO;
	if (choice == nil) {
		startingFromLeftMost = YES;
		choice = rootWindow;
		
		while (choice != nil && [choice isKindOfClass: [GlkPairWindow class]]) {
			if (forward)
				choice = [(GlkPairWindow*)choice keyWindow];
			else
				choice = [(GlkPairWindow*)choice nonKeyWindow];
		}
	}
	if (choice == nil) return;
	
	// If we haven't got a window that's waiting for keyboard input, try looking again
	if (![choice waitingForKeyboardInput]) {
		if (!keepLooking) return;
		[self performTabFrom: choice
					 forward: forward
				 keepLooking: !startingFromLeftMost];
		return;
	}
	
	// Focus on the choice
	[[self window] makeFirstResponder: [choice windowResponder]];
}

- (void) performTabFrom: (GlkWindow*) window
				forward: (BOOL) forward {
	[self performTabFrom: window
				 forward: forward
			 keepLooking: YES];
}

// = Accessibility =

- (NSString *)accessibilityActionDescription: (NSString*) action {
	return [super accessibilityActionDescription:  action];
}

- (NSArray *)accessibilityActionNames {
	return [super accessibilityActionNames];
}

- (BOOL)accessibilityIsAttributeSettable:(NSString *)attribute {
	return [super accessibilityIsAttributeSettable: attribute];;
}

- (void)accessibilityPerformAction:(NSString *)action {
	[super accessibilityPerformAction: action];
}

- (void)accessibilitySetValue: (id)value
				 forAttribute: (NSString*) attribute {
	[super accessibilitySetValue: value
					forAttribute: attribute];
}

- (NSArray*) accessibilityAttributeNames {
	NSMutableArray* result = [[[super accessibilityAttributeNames] mutableCopy] autorelease];
	if (!result) result = [[[NSMutableArray alloc] init] autorelease];
	
	[result addObjectsFromArray:[NSArray arrayWithObjects: 
		NSAccessibilityContentsAttribute,
		NSAccessibilityChildrenAttribute,
		NSAccessibilityHelpAttribute,
		NSAccessibilityDescriptionAttribute,
		NSAccessibilityTitleAttribute,
		NSAccessibilityFocusedUIElementAttribute,
		nil]];
	
	return result;
}

- (id) accessibilityFocusedUIElement {
	NSResponder* firstResponder = [[self window] firstResponder];
	
	if (firstResponder == nil) return self;
	
	if ([firstResponder isKindOfClass: [NSView class]]) {
		NSView* windowView = (NSView*) firstResponder;
		
		while (windowView != nil) {
			if ([windowView isKindOfClass: [GlkWindow class]]) {
				return windowView;
			}
			
			windowView = [windowView superview];
		}
	}
	
	return [super accessibilityFocusedUIElement];
}

- (id)accessibilityAttributeValue:(NSString *)attribute {
	if ([attribute isEqualToString: NSAccessibilityChildrenAttribute]
		|| [attribute isEqualToString: NSAccessibilityContentsAttribute]) {
		//return [NSArray arrayWithObjects: rootWindow, nil];
	} else if ([attribute isEqualToString: NSAccessibilityFocusedUIElementAttribute]) {
		return [self accessibilityFocusedUIElement];
	} else if ([attribute isEqualToString: NSAccessibilityHelpAttribute]
			   || [attribute isEqualToString: NSAccessibilityDescriptionAttribute]) {
		NSString* description = @"an interactive fiction game";
		if (delegate && [delegate respondsToSelector: @selector(taskDescription)]) {
			description = [delegate taskDescription];
		}
		return [NSString stringWithFormat: @"%@ %@", running?@"Running":@"Finished", description];
	} else if ([attribute isEqualToString: NSAccessibilityRoleDescriptionAttribute]) {
		return @"GLK view";
	} else if ([attribute isEqualToString: NSAccessibilityRoleAttribute]) {
		return NSAccessibilityGroupRole;
	}
	

	NSLog(@"%@", attribute);

	return [super accessibilityAttributeValue: attribute];
}

- (BOOL)accessibilityIsIgnored {
	return NO;
}

@end
