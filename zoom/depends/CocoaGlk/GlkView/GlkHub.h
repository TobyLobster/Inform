//
//  GlkHub.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkHubProtocol.h>

//
// The hub is the first point that a client connects to the Glk server application.
//
//	The hub should be named, unless you want any random Glk application connecting. No hubs are available until a name has been 
//		set.
//	Setting a hub cookie increases security, but you must communicate it to the client tasks somehow. Using a keychain cookie is
//		one way around this.
//	Always set the hub name after the cookie if you are using cookies.
//
// Client tasks by default connect to the hub named CocoaGlk.
//
@interface GlkHub : NSObject<GlkHub> {
	// Hub data
	NSString* hubName;										// Name of the hub
	NSString* cookie;										// Hub cookie (clients must know this to connect)
	
	id delegate;											// The delegate (used to create anonymous sessions)
	
	NSMutableDictionary* waitingSessions;					// Sessions waiting for a connection (maps cookies to sessions)
	
	// The connection
	NSConnection* connection;								// The point at which the clients can connect to us
}

// The shared hub
+ (GlkHub*) sharedGlkHub;									// Creating your own hub is liable to be hairy and unsupported. You only need one per task anyway.

// Naming
- (void) setHubName: (NSString*) hubName;					// The name of this GlkHub. Calls resetConnection.
- (void) useProcessHubName;									// Auto-generates a name based on the process name
- (NSString*) hubName;

// Security
- (void) setHubCookie: (NSString*) hubCookie;				// Clients must know this in order to connect to the hub. nil by default.
- (void) setRandomHubCookie;								// Auto-generates a cookie. Not cryptographically secure (yet).
- (void) setKeychainHubCookie;								// Auto-generates (if no cookie exists yet) and stores the hub cookie in the keychain.
- (NSString*) hubCookie;

// The connection
- (void) resetConnection;									// Starts listening for connections if we're not already

// Registering sessions for later consumption
- (void) registerSession: (NSObject<GlkSession>*) session	// Registers a session with the given cookie. A client can request this specific session object (exactly one, though)
			  withCookie: (NSString*) sessionCookie;
- (void) unregisterSession: (NSObject<GlkSession>*)session;	// Unregisters a session previously registered with registerSession

// The delegate
- (void) setDelegate: (id) hubDelegate;
- (id)   delegate;

@end

// Hub delegate functions
@interface NSObject(GlkHubDelegate)

- (NSObject<GlkSession>*) createAnonymousSession;			// Usually should return a GlkView. Called when a task starts with no session cookie

@end
