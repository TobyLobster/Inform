//
//  IFHistoryEvent.h
//  Inform
//
//  Created by Andrew Hunter on 23/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//
// This represents an event in the history of a project pane. (Ie, an action
// to perform when the backwards or forwards buttons are pressed)
//
@interface IFHistoryEvent : NSObject

// Initialisation

- (instancetype) init NS_UNAVAILABLE;
/// Initialise with the specified invocation
- (instancetype) initWithInvocation: (NSInvocation*) invocation NS_DESIGNATED_INITIALIZER;
/// Initialise with the specified object as an invocation target
- (instancetype) initWithObject: (id) target NS_DESIGNATED_INITIALIZER;

// Building the invocation

/// The target for the proxy object
@property (atomic, readwrite, strong) id target;
/// The proxy object to use for this history item
@property (atomic, readonly, strong) id proxy;

// Replaying

/// Replays the event specified by this object
- (void) replay;

@end
