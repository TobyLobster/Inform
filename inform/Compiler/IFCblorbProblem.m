//
//  IFCblorbProblem.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 28/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "IFCblorbProblem.h"


@implementation IFCblorbProblem

- (id) initWithBuildDir: (NSString*) newBuildDir {
	self = [super init];
	
	if (self) {
		buildDir = [newBuildDir copy];
	}
	
	return self;
}

- (void) dealloc {
	[buildDir autorelease]; buildDir = nil;
	
	[super dealloc];
}

- (NSURL*) urlForProblemWithErrorCode: (int) errorCode {
	// If a build directory is supplied, then look there for the error file
	if (buildDir) {
		NSString* errorPath = [buildDir stringByAppendingPathComponent: @"StatusCblorb.html"];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath: errorPath]) {
			return [NSURL fileURLWithPath: errorPath];
		}
	}
	
	// Otherwise, use the default
	return [NSURL URLWithString: @"inform:/ErrorCblorb.html"];
}

- (NSURL*) urlForSuccess {
	// If a build directory is supplied, then look there for the error file
	if (buildDir) {
		NSString* errorPath = [buildDir stringByAppendingPathComponent: @"StatusCblorb.html"];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath: errorPath]) {
			return [NSURL fileURLWithPath: errorPath];
		}
	}
	
	// Otherwise, use the default
	return [NSURL URLWithString: @"inform:/GoodCblorb.html"];
}

@end
