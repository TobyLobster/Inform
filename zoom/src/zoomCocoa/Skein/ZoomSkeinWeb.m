//
//  ZoomSkeinWeb.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

//
// These classes are designed to allow a ZoomSkeinView to be embedded in a web view
// MIME type is application/x-zoom-skein
//

#import "ZoomSkein.h"
#import "ZoomSkeinWeb.h"
#import <ZoomView/ZoomView-Swift.h>

@implementation ZoomSkein(ZoomSkeinWebDocRepresentation)

- (NSString *)title {
	return @"Skein";
}

- (NSString *)documentSource {
	return [self xmlData];
}

- (BOOL)canProvideDocumentSource {
	return YES; // AKA trueYES according to Apple's webkit docs
}

- (void)setDataSource:(__unused WebDataSource *)dataSource {
	webData = [[NSMutableData alloc] init];
	
	NSLog(@"ZoomSkein: loading from web");
}

- (void) receivedError: (__unused NSError *)error
		withDataSource: (__unused WebDataSource *)dataSource {
	NSLog(@"ZoomSkein: received error");
	
	if (webData) {
		webData = nil;
	}
}

- (void) receivedData:(NSData *)data 
	   withDataSource:(__unused WebDataSource *)dataSource {
	NSLog(@"ZoomSkein: received data");

	if (webData) {
		[webData appendData: data];
	}
}

- (void)finishedLoadingWithDataSource:(__unused WebDataSource *)dataSource {
	NSLog(@"ZoomSkein: finished loading");

	if (webData) {
		[self parseXmlData: webData error: NULL];
		webData = nil;
	}
}

@end
