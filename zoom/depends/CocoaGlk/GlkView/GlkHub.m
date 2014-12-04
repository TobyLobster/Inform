//
//  GlkHub.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkHub.h"

#include <sys/types.h>
#include <unistd.h>

@implementation GlkHub

// = The shared hub =

+ (GlkHub*) sharedGlkHub {
	static GlkHub* hub = nil;
	
	if (!hub) {
		hub = [[GlkHub alloc] init];
	}
	
	return hub;
}

// = Initialisation =

- (id) init {
	self = [super init];
	
	if (self) {
		waitingSessions = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	[delegate release]; delegate = nil;

	[hubName release]; hubName = nil;
	[cookie release]; cookie = nil;
	
	[waitingSessions release]; waitingSessions = nil;
	
	if (connection) [connection registerName: nil];
	[connection release]; connection = nil;
	
	[super dealloc];
}

// = The connection =

- (void) resetConnection {
	if (hubName == nil) {
		hubName = [@"CocoaGlk" retain];
	}
	
	if (connection) {
		// Kill off any old connection
		[connection registerName: nil];			// As anything using the connection will likely retain it
		[connection release];					// We're done with this connection
		connection = nil;
	}
	
	NSString* connectionName = [NSString stringWithFormat: @"97V36B3QYK.com.inform7.inform-compiler.CocoaGlk-%@", hubName];
	NSPort* port = [NSMachPort port];
	
	connection = [[NSConnection connectionWithReceivePort: port
												 sendPort: port] retain];
	[connection setRootObject: self];
	// [connection addRequestMode: NSEventTrackingRunLoopMode]; // Causes a crash :-(. Would allow the client to update while resizing if it worked
	[connection addRunLoop: [NSRunLoop currentRunLoop]];
	if (![connection registerName: connectionName]) {
		NSLog(@"Uh-oh: failed to register a connection. Glk clients will probably fail to start");
	}
}


// = Registering sessions for later consumption =

- (void) registerSession: (NSObject<GlkSession>*) session
			  withCookie: (NSString*) sessionCookie {
	if ([waitingSessions objectForKey: sessionCookie] != nil) {
		// Oops! This is not allowed
		[NSException raise: @"GlkHubSessionAlreadyExistsException"
					format: @"An attempt was made to register a session with the same cookie as an pre-existing session"];
		return;
	}
	
	[waitingSessions setObject: session
						forKey: sessionCookie];
}

- (void) unregisterSession: (NSObject<GlkSession>*)session {
	// Iterate through the sessions until we find the one that we're supposed to be removing
	NSEnumerator* sesEnum = [waitingSessions keyEnumerator];
	NSString* sessionCookie;
	NSObject<GlkSession>* ses;
	
	while (sessionCookie = [sesEnum nextObject]) {
		ses = [waitingSessions objectForKey: sessionCookie];

		if (ses == session) {
			// This is the session to remove
			[[[waitingSessions objectForKey: sessionCookie] retain] autorelease];
			[waitingSessions removeObjectForKey: sessionCookie];
			break;
		}
	}
}

// = Naming =

- (void) setHubName: (NSString*) newHubName {
	if (hubName) [hubName release];
	
	hubName = [newHubName copy];
	
	[self resetConnection];
}

- (void) useProcessHubName {
	[self setHubName: [NSString stringWithFormat: @"GlkHub-%04x", getpid()]];
}

- (NSString*) hubName {
	return hubName;
}

// = Security =

- (void) setHubCookie: (NSString*) newHubCookie {
	if (cookie) [cookie release];
	
	cookie = [newHubCookie copy];
}

- (void) setRandomHubCookie {
	unichar randomCookie[16];
	int x;
	
	for (x=0; x<16; x++) {
		randomCookie[x] = random()%94 + 32;
	}
	
	[self setHubCookie: [NSString stringWithCharacters: randomCookie
												length: 16]];
}

- (void) setKeychainHubCookie {
	[self setRandomHubCookie];
}

- (NSString*) hubCookie {
	return cookie;
}

// = Setting up the session =

- (byref NSObject<GlkSession>*) createNewSession {
	return [self createNewSessionWithHubCookie: nil
								 sessionCookie: nil];
}

- (byref NSObject<GlkSession>*) createNewSessionWithHubCookie: (in bycopy NSString*) hubCookie {
	return [self createNewSessionWithHubCookie: hubCookie
								 sessionCookie: nil];
}

- (byref NSObject<GlkSession>*) createNewSessionWithHubCookie: (in bycopy NSString*) hubCookie
                                                sessionCookie: (in bycopy NSString*) sessionCookie {
	if (sessionCookie == nil) {
		return [self createAnonymousSession];
	} else {
		// Look up the session in the session dictionary
		NSObject<GlkSession>* session = [waitingSessions objectForKey: sessionCookie];
		if (session == nil) return nil;
		
		// Remove the session from the dictionary
		[session retain];
		[waitingSessions removeObjectForKey: sessionCookie];
		
		// Return the retrieved session object
		return [session autorelease];
	}
}

// = The delegate =

- (void) setDelegate: (id) hubDelegate {
	if (delegate) [delegate release];
	delegate = [hubDelegate retain];
}

- (id) delegate {
	return delegate;
}

- (NSObject<GlkSession>*) createAnonymousSession {
	if (delegate && [delegate respondsToSelector: @selector(createAnonymousSession)]) {
		return [delegate createAnonymousSession];
	} else {
		return nil;
	}
}

@end
