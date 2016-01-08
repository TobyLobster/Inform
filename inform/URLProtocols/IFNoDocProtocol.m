//
//  IFNoDocProtocol.m
//  Inform
//
//  Created by Andrew Hunter on Mon May 17 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFNoDocProtocol.h"


@implementation IFNoDocProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
	if ([[[request URL] scheme] isEqualToString: @"nodoc"]) 
		return YES;
	return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
	return [[NSURLRequest alloc] initWithURL: [[NSURL alloc] initWithString: @"nodoc:"]];
}

-(NSCachedURLResponse *)cachedResponse {
	return [[NSCachedURLResponse alloc] initWithResponse: [[NSURLResponse alloc] init]
													 data: [@"<html><body>No data</body></html>" dataUsingEncoding: NSUTF8StringEncoding]];
}

-(id <NSURLProtocolClient>)client {
	return nil;
}

- (void) startLoading {
}

- (void) stopLoading {
}

@end
