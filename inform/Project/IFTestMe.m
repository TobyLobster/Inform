//
//  IFTestMe.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 18/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import "IFTestMe.h"


@implementation IFTestMe

- (id) init {
	self = [super init];
	
	if (self) {
		commands = [[NSMutableArray alloc] init];
		[commands addObject: @"test me"];
	}
	
	return self;
}

- (void) dealloc {
	[commands release];
	[super dealloc];
}

- (NSString*) nextCommand {
	if ([commands count] <= 0) return nil;
	
	NSString* nextCommand = [[[commands objectAtIndex: 0] copy] autorelease];
	[commands removeObjectAtIndex: 0];
	return nextCommand;
}

- (BOOL) disableMorePrompt {
	return YES;
}

@end
