//
//  IFHistoryEvent.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 23/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFHistoryEvent.h"

//
// Internal class used to create history events by proxy
//
@interface IFHistoryEventProxy : NSProxy {
	IFHistoryEvent* event;
}

- (id) initWithEvent: (IFHistoryEvent*) event;

@end

@implementation IFHistoryEvent


// = Initialisation =

- (id) initWithInvocation: (NSInvocation*) newInvocation {
	self = [super init];
	
	if (self) {
		invocations = [[NSMutableArray alloc] initWithObjects: newInvocation, nil];
		target = nil;
	}
	
	return self;
}

- (id) initWithObject: (id) newTarget {
	self = [super init];
	
	if (self) {
		invocations = [[NSMutableArray alloc] init];
		target = [newTarget retain];
	}
	
	return self;
}

- (void) dealloc {
	[target release];
	[invocations release];
	
	[super dealloc];
}
	
// = Building the invocation =

- (void) setTarget: (id) newTarget {
	[target release];
	target = [newTarget retain];
}

- (id) proxy {
	return [[[IFHistoryEventProxy alloc] initWithEvent: self] autorelease];
}

- (id) target {
	return target;
}

- (void) addInvocation: (NSInvocation*) newInvocation {
	[newInvocation retainArguments];
	[invocations addObject: newInvocation];
	
	[target release]; target = nil;
}

// = Replaying =

- (void) replay {
	[invocations makeObjectsPerformSelector: @selector(invoke)];
}

@end

// = IFHistoryEventProxy =

@implementation IFHistoryEventProxy

- (id) initWithEvent: (IFHistoryEvent*) newEvent {
	// self = [super init];
	
	if (self) {
		event = [newEvent retain];
	}
	
	return self;
}

- (void) dealloc {
	[event release];
	
	[super dealloc];
}

+ (BOOL)respondsToSelector:(SEL)aSelector {
	return YES;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
	return [[event target] methodSignatureForSelector: aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
	NSInvocation* invoke = [[anInvocation retain] autorelease];
	
	[invoke setTarget: [event target]];
	[invoke retainArguments];
	[event addInvocation: invoke];
}

@end
