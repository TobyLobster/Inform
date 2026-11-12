//
//  IFHistoryEvent.m
//  Inform
//
//  Created by Andrew Hunter on 23/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFHistoryEvent.h"

@implementation IFHistoryEvent {
    /// The actions to perform when this history item is replayed, in order
    NSMutableArray<void (^)(void)>* actions;
}


#pragma mark - Initialisation

- (instancetype) init {
	self = [super init];
	
	if (self) {
		actions = [[NSMutableArray alloc] init];
	}
	
	return self;
}

	
#pragma mark - Recording

- (void) addAction: (void (^)(void)) action {
    [actions addObject: [action copy]];
}

#pragma mark - Replaying

- (void) replay {
    for (void (^action)(void) in actions) {
        action();
    }
}

@end

