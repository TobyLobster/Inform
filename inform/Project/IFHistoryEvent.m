//
//  IFHistoryEvent.m
//  Inform
//
//  Created by Andrew Hunter on 23/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFHistoryEvent.h"

///
/// Internal class used to create history events by proxy
///
@interface IFHistoryEventProxy : NSProxy

- (instancetype) initWithEvent: (IFHistoryEvent*) event;

@end

@implementation IFHistoryEvent {
    /// The action(s) to perform when this history item is replayed
    NSMutableArray* invocations;
    /// The target to use when building the invocation by proxy
    id target;
}


#pragma mark - Initialisation

- (instancetype) initWithInvocation: (NSInvocation*) newInvocation {
	self = [super init];
	
	if (self) {
		invocations = [[NSMutableArray alloc] initWithObjects: newInvocation, nil];
		target = nil;
	}
	
	return self;
}

- (instancetype) initWithObject: (id) newTarget {
	self = [super init];
	
	if (self) {
		invocations = [[NSMutableArray alloc] init];
		target = newTarget;
	}
	
	return self;
}

	
#pragma mark - Building the invocation

@synthesize target;

- (id) proxy {
	return [[IFHistoryEventProxy alloc] initWithEvent: self];
}

- (void) addInvocation: (NSInvocation*) newInvocation {
	[newInvocation retainArguments];
	[invocations addObject: newInvocation];
	
    target = nil;
}

#pragma mark - Replaying

- (void) replay {
	[invocations makeObjectsPerformSelector: @selector(invoke)];
}

@end

#pragma mark - IFHistoryEventProxy

@implementation IFHistoryEventProxy {
    IFHistoryEvent* event;
}

- (instancetype) initWithEvent: (IFHistoryEvent*) newEvent {
	// self = [super init];
	
	if (self) {
		event = newEvent;
	}
	
	return self;
}


+ (BOOL)respondsToSelector:(SEL)aSelector {
	return YES;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
	return [event.target methodSignatureForSelector: aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
	NSInvocation* invoke = anInvocation;
	
	invoke.target = event.target;
	[invoke retainArguments];
	[event addInvocation: invoke];
}

@end
