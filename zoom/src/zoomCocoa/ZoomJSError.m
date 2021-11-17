//
//  ZoomJSError.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 25/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomJSError.h"


@implementation ZoomJSError

#pragma mark - Initialisation

#pragma mark - JavaScript names for our selectors

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

#pragma mark - Dealing with errors

@synthesize lastError;

@end
