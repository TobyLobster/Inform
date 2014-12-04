//
//  ZoomJSError.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 25/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomJSError.h"


@implementation ZoomJSError

// = Initialisation =

- (void) dealloc {
	[lastError release];
	[super dealloc];
}

// = JavaScript names for our selectors =

+ (NSString *) webScriptNameForSelector: (SEL)sel {
	if (sel == @selector(lastError)) {
		return @"LastError";
	}	
	return nil;
}

+ (BOOL) isSelectorExcludedFromWebScript: (SEL)sel {
	if (sel == @selector(lastError)) {
		return NO;
	}
	
	return YES;
}

// = Dealing with errors =

- (NSString*) lastError {
	return lastError;
}

- (void) setLastError: (NSString*) newLastError {
	[lastError release];
	lastError = [newLastError copy];
}

@end
