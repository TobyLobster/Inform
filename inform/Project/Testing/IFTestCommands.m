//
//  IFTestCommands.m
//  Inform
//
//  Created by Andrew Hunter on 18/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import "IFTestCommands.h"


@implementation IFTestCommands {
    NSMutableArray* commands;
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		commands = [[NSMutableArray alloc] init];
	}
	
	return self;
}


- (NSString*) nextCommand {
	if ([commands count] <= 0) return nil;
	
	NSString* nextCommand = [commands[0] copy];
	[commands removeObjectAtIndex: 0];
	return nextCommand;
}

- (BOOL) disableMorePrompt {
	return YES;
}

-(void) setCommands:(NSArray*) myCommands {
    commands = [myCommands mutableCopy];
}

@end
