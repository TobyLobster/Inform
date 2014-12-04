//
//  IFHistoryEvent.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 23/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//
// This represents an event in the history of a project pane. (Ie, an action
// to perform when the backwards or forwards buttons are pressed)
//
@interface IFHistoryEvent : NSObject {
	NSMutableArray* invocations;							// The action(s) to perform when this history item is replayed
	id target;												// The target to use when building the invocation by proxy
}

// Initialisation

- (id) initWithInvocation: (NSInvocation*) invocation;		// Initialise with the specified invocation
- (id) initWithObject: (id) target;							// Initialise with the specified object as an invocation target

// Building the invocation

- (void) setTarget: (id) newTarget;							// Sets the target for the proxy object
- (id) proxy;												// The proxy object to use for this history item

// Replaying

- (void) replay;											// Replays the event specified by this object

@end
