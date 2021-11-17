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

@implementation GlkHub {
	// The connection
	/// The point at which the clients can connect to us
	NSConnection* connection;
}

#pragma mark - The shared hub

+ (GlkHub*) sharedGlkHub {
	static GlkHub* hub = nil;
	
	if (!hub) {
		hub = [[GlkHub alloc] init];
	}
	
	return hub;
}

#pragma mark - Initialisation

- (id) init {
	self = [super init];
	
	if (self) {
		waitingSessions = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	if (connection) [connection registerName: nil];
}

#pragma mark - The connection

- (void) resetConnection {
	if (hubName == nil) {
		hubName = @"CocoaGlk";
	}
	
	if (connection) {
		// Kill off any old connection
		[connection registerName: nil];			// As anything using the connection will likely retain it
		connection = nil;						// We're done with this connection
	}
	
	NSString* connectionName = [NSString stringWithFormat: @"CocoaGlk-%@", hubName];
	NSPort* port = [NSMachPort port];
	
	connection = [NSConnection connectionWithReceivePort: port
												sendPort: port];
	[connection setRootObject: self];
	// [connection addRequestMode: NSEventTrackingRunLoopMode]; // Causes a crash :-(. Would allow the client to update while resizing if it worked
	[connection addRunLoop: [NSRunLoop currentRunLoop]];
	if (![connection registerName: connectionName]) {
		NSLog(@"Uh-oh: failed to register a connection. Glk clients will probably fail to start");
	}
}


#pragma mark - Registering sessions for later consumption

- (void) registerSession: (id<GlkSession>) session
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

- (void) unregisterSession: (id<GlkSession>)session {
	// Iterate through the sessions until we find the one that we're supposed to be removing
	for (NSString* sessionCookie in waitingSessions) {
		id<GlkSession> ses = [waitingSessions objectForKey: sessionCookie];

		if (ses == session) {
			// This is the session to remove
//			[[[waitingSessions objectForKey: sessionCookie] retain] autorelease];
			[waitingSessions removeObjectForKey: sessionCookie];
			break;
		}
	}
}

#pragma mark - Naming

- (void) setHubName: (NSString*) newHubName {
	hubName = [newHubName copy];
	
	[self resetConnection];
}

- (void) useProcessHubName {
	[self setHubName: [NSString stringWithFormat: @"GlkHub-%04x", getpid()]];
}

@synthesize hubName;

#pragma mark - Security

@synthesize hubCookie=cookie;

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

#pragma mark - Setting up the session

- (byref id<GlkSession>) createNewSession {
	return [self createNewSessionWithHubCookie: nil
								 sessionCookie: nil];
}

- (byref id<GlkSession>) createNewSessionWithHubCookie: (in bycopy NSString*) hubCookie {
	return [self createNewSessionWithHubCookie: hubCookie
								 sessionCookie: nil];
}

- (byref id<GlkSession>) createNewSessionWithHubCookie: (in bycopy NSString*) hubCookie
										 sessionCookie: (in bycopy NSString*) sessionCookie {
	if (sessionCookie == nil) {
		return [self createAnonymousSession];
	} else {
		// Look up the session in the session dictionary
		id<GlkSession> session = [waitingSessions objectForKey: sessionCookie];
		if (session == nil) return nil;
		
		// Remove the session from the dictionary
		[waitingSessions removeObjectForKey: sessionCookie];
		
		// Return the retrieved session object
		return session;
	}
}

#pragma mark - The delegate

@synthesize delegate;

- (id<GlkSession>) createAnonymousSession {
	if (delegate && [delegate respondsToSelector: @selector(createAnonymousSession)]) {
		return [delegate createAnonymousSession];
	} else {
		return nil;
	}
}

@end
