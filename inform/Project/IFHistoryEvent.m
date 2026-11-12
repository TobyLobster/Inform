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
    /// The actions to perform when this history item is replayed, in order
    NSMutableArray<void (^)(void)>* actions;
    /// The target to use when building the invocation by proxy
    id target;
}


#pragma mark - Initialisation

- (instancetype) initWithObject: (id) newTarget {
	self = [super init];
	
	if (self) {
		actions = [[NSMutableArray alloc] init];
		target = newTarget;
	}
	
	return self;
}

	
#pragma mark - Building the invocation

@synthesize target;

- (id) proxy {
	return [[IFHistoryEventProxy alloc] initWithEvent: self];
}

- (void) addAction: (void (^)(void)) action {
    [actions addObject: [action copy]];
}

- (void) addInvocation: (NSInvocation*) newInvocation {
	[newInvocation retainArguments];
	[self addAction: ^{
        [newInvocation invoke];
    }];
	
    target = nil;
}

#pragma mark - Replaying

- (void) replay {
    for (void (^action)(void) in actions) {
        action();
    }
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
