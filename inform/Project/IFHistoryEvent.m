//
//  IFHistoryEvent.m
//  Inform
//
//  Created by Andrew Hunter on 23/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFHistoryEvent.h"

//
// Internal class used to create history events by proxy
//
@interface IFHistoryEventProxy : NSProxy

- (instancetype) initWithEvent: (IFHistoryEvent*) event;

@end

@implementation IFHistoryEvent {
    NSMutableArray* invocations;							// The action(s) to perform when this history item is replayed
    id target;												// The target to use when building the invocation by proxy
}


// = Initialisation =
- (instancetype) init { self = [super init]; return self; }

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

	
// = Building the invocation =

- (void) setTarget: (id) newTarget {
	target = newTarget;
}

- (id) proxy {
	return [[IFHistoryEventProxy alloc] initWithEvent: self];
}

- (id) target {
	return target;
}

- (void) addInvocation: (NSInvocation*) newInvocation {
	[newInvocation retainArguments];
	[invocations addObject: newInvocation];
	
	 target = nil;
}

// = Replaying =

- (void) replay {
	[invocations makeObjectsPerformSelector: @selector(invoke)];
}

@end

// = IFHistoryEventProxy =

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
	return [[event target] methodSignatureForSelector: aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
	NSInvocation* invoke = anInvocation;
	
	[invoke setTarget: [event target]];
	[invoke retainArguments];
	[event addInvocation: invoke];
}

@end
