//
//  glk_cocoa.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#include <sys/types.h>
#include <unistd.h>

#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import "GlkSessionProtocol.h"

#include "glk.h"
#import "cocoaglk.h"
#import "glk_client.h"

@class GlkCocoa;

#pragma mark - Variables

#if !defined(COCOAGLK_IPHONE)
/// Remote object that allows us to create sessions
id<GlkHub> cocoaglk_hub = nil;
/// Object that is notified when the remote session finishes
static GlkCocoa* cocoaglk_obj = nil;
#endif

/// The active session
id<GlkSession> cocoaglk_session = nil;
/// The global buffer
GlkBuffer* cocoaglk_buffer = nil;

/// The autorelease pool
NSAutoreleasePool* cocoaglk_pool = nil;

#pragma mark - Object we use to receive some events

@interface GlkCocoa : NSObject

- (void) connectionDied: (NSNotification*) not;

@end

@implementation GlkCocoa

- (void) connectionDied: (NSNotification*) not {
	if (cocoaglk_interrupt) {
		cocoaglk_interrupt();
	}
	
	NSLog(@"Connection died");
#if defined(COCOAGLK_IPHONE)
	[NSThread exit];
#else
	exit(1);
#endif
}

@end

#pragma mark - Starting up

#if !defined(COCOAGLK_IPHONE)

void cocoaglk_start(int argv, const char** argc) {
	[cocoaglk_pool release];
	cocoaglk_pool = [[NSAutoreleasePool alloc] init];
	
	// Parse arguments
	//
	// There are only a few arguments supported here:
	//  -hubname <name>	- specifies the hub to connect to.
	//			If none is specified, then the default CocoaGlk hub name is used.
	//	-hubcookie <cookie> - specifies the hub cookie to use to start this application (as an ASCII string)
	//			If not specified, a nil hub cookie will be tried, followed by a keychain hub cookie.
	//	-sessioncookie <cookie> - specifies the session cookie to use to connect to a specific session
	//			If not specified, this will request a spontaneous session to be created.
	int arg;
	const char* hubName = NULL;
	const char* hubCookie = NULL;
	const char* sessionCookie = NULL;
	
	for (arg=1; arg<argv-1; arg++) {
		// Note that there's guaranteed to be a following argument here
		if (strcmp(argc[arg], "-hubname") == 0) {
			hubName = argc[arg+1]; arg++;
		} else if (strcmp(argc[arg], "-hubcookie") == 0) { 
			hubCookie = argc[arg+1]; arg++;
		} else if (strcmp(argc[arg], "-sessioncookie") == 0) {
			sessionCookie = argc[arg+1]; arg++;
		}
	}
	
	// If some arguments aren't set, then we can try the environment
	if (hubName == NULL) hubName = getenv("GlkHubName");
	if (hubCookie == NULL) hubCookie = getenv("GlkHubCookie");
	if (sessionCookie == NULL) sessionCookie = getenv("GlkSessionCookie");
	
	// There's a default hub name if all else fails
	if (hubName == NULL) hubName = "CocoaGlk";
	
#if COCOAGLK_DEBUG
	NSLog(@"Client ready: hub name %s, cookie %s, session cookie %s", hubName, hubCookie, sessionCookie);
#endif
	
	// Create the base object
	cocoaglk_obj = [[GlkCocoa alloc] init];
	
	// Attempt to connect to the hub
	NSString* hubNameS = [NSString stringWithUTF8String: hubName];
	NSString* hubCookieS = nil;
	NSString* sessionCookieS = nil;
	
	if (hubCookie) hubCookieS = [NSString stringWithUTF8String: hubCookie];
	if (sessionCookie) sessionCookieS = [NSString stringWithUTF8String: sessionCookie];
	
	NSString* connectionName = [NSString stringWithFormat: @"CocoaGlk-%@", hubNameS];
	
	NSConnection* remoteConnection = [NSConnection connectionWithRegisteredName: connectionName
																		   host: nil];
	
	if (remoteConnection == nil) {
		NSLog(@"Failed to connect to Glk hub with name %s", hubName);
		NSLog(@"Unable to open display. Quitting");
		exit(1);
	}
	
	cocoaglk_hub = (id<GlkHub>)[remoteConnection rootProxy];
	
	if (cocoaglk_hub == nil) {
		NSLog(@"Failed to retrieve hub object");
		NSLog(@"Unable to open display. Quitting");
		exit(1);
	}
	
	if (![cocoaglk_hub conformsToProtocol: @protocol(GlkHub)]) {
		NSLog(@"Remote hub does not conform to the GlkHub protocol");
		NSLog(@"Unable to open display. Quitting");
		exit(1);
	}
	
	[(NSDistantObject*) cocoaglk_hub setProtocolForProxy: @protocol(GlkHub)];
	
	// Give up if the connection ever dies
	[[NSNotificationCenter defaultCenter] addObserver: cocoaglk_obj
											 selector: @selector(connectionDied:)
												 name: NSConnectionDidDieNotification
											   object: remoteConnection];
	
	// Attempt to open the session
	if (hubCookieS == nil && sessionCookieS == nil) {
		// Unauthenticated
		cocoaglk_session = [[cocoaglk_hub createNewSession] retain];
	} else if (sessionCookieS == nil) {
		// No session cookie
		cocoaglk_session = [[cocoaglk_hub createNewSessionWithHubCookie: hubCookieS] retain];
	} else {
		// Session and hub cookies (or session cookie and no hub cookie)
		cocoaglk_session = [[cocoaglk_hub createNewSessionWithHubCookie: hubCookieS
														  sessionCookie: sessionCookieS] retain];
	}
	
	// If we haven't got a valid session, then authentication likely failed
	if (cocoaglk_session == nil) {
		NSLog(@"Failed to connect to Glk hub: failed to create session (most likely due to a bad cookie)");
		NSLog(@"Unable to open display. Quitting");
		exit(1);
	}
	
	[(NSDistantObject*) cocoaglk_session setProtocolForProxy: @protocol(GlkSession)];
	
	// We're connected and we have a session
	cocoaglk_buffer = [[GlkBuffer alloc] init];
	
	// Tell the session we're here
	[cocoaglk_session clientHasStarted: getpid()];
}

#endif

/// Reports a warning to the server
void cocoaglk_warning(const char* warningText) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: cocoaglk_warning(\"%s\")", warningText);
#endif

	cocoaglk_flushbuffer("About to show a warning");
	
	NSString* warningString = [[NSString alloc] initWithBytes: warningText
													   length: strlen(warningText)
													 encoding: NSISOLatin1StringEncoding];
	[cocoaglk_session showWarning: warningString];
	[warningString release];
}

/// Reports an error to the server, then quits
void cocoaglk_error(const char* errorText) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: cocoaglk_error(\"%s\")", errorText);
#endif

	static BOOL showingError = NO;
	if (!showingError) {
		showingError = YES;
		
		cocoaglk_flushbuffer("About to show an error");
		
		NSString* errorString = [[NSString alloc] initWithBytes: errorText
														 length: strlen(errorText)
													   encoding: NSISOLatin1StringEncoding];
		[cocoaglk_session showError: errorString];

		if (cocoaglk_interrupt) cocoaglk_interrupt();
		[cocoaglk_session clientHasFinished];
		
		showingError = NO;

#if defined(COCOAGLK_IPHONE)
		// Kill the interpreter thread
		[NSThread exit];
#else
		// Kill the interpreter task
		exit(1);
#endif
	}
}

/// Logs a message to the server
void cocoaglk_log(const char* logText) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: cocoaglk_log(\"%s\")", logText);
#endif
	
	cocoaglk_flushbuffer("About to show a log message");
	
	NSString* logString = [[NSString alloc] initWithBytes: logText
												   length: strlen(logText)
												 encoding: NSISOLatin1StringEncoding];
	[cocoaglk_session logMessage: logString];
	[logString release];
}

/// Logs a message with priority to the server
void cocoaglk_log_ex(const char* logText, int priority) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: cocoaglk_log_ex(\"%s\", %i)", logText, priority);
#endif
	
	cocoaglk_flushbuffer("About to show a log message");
	
	NSString* logString = [[NSString alloc] initWithBytes: logText
												   length: strlen(logText)
												 encoding: NSISOLatin1StringEncoding];
	[cocoaglk_session logMessage: logString
					withPriority: priority];
	[logString release];
}

/// Flushes the buffer
void cocoaglk_flushbuffer(const char* reason) {
	// Sanity checking
	if (cocoaglk_session == nil) {
		cocoaglk_error("Attempt to flush buffer when there is no Glk session available");
	}
	
	static BOOL flushing = NO;
	
	if (flushing) {
		NSLog(@"Recursive buffer flush?! (%s)", reason);
		return;
	}
	
	flushing = YES;
	
	// Flush the buffer
	if ([cocoaglk_buffer shouldBeFlushed]) {
#if COCOAGLK_TRACE
		NSLog(@"Main buffer flushing: %s", reason);
#endif
		
		[cocoaglk_session performOperationsFromBuffer: cocoaglk_buffer];
				
		[cocoaglk_buffer release];
		cocoaglk_buffer = [[GlkBuffer alloc] init];
		
		cocoaglk_loopIteration = (int)[cocoaglk_session synchronisationCount];
		
#if COCOAGLK_TRACE
		NSLog(@"Main buffer flushed");
#endif
	}
	
	flushing = NO;
}
