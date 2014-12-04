//
//  GlkMemoryFileRef.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 12/11/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "GlkMemoryFileRef.h"
#import "GlkMemoryStream.h"


@implementation GlkMemoryFileRef

- (id) initWithData: (NSData*) fileData {
	self = [super init];
	
	if (self) {
		data = [fileData retain];
	}
	
	return self;
}

- (void) dealloc {
	[data release];
	[super dealloc];
}

- (byref NSObject<GlkStream>*) createReadOnlyStream {
	return [[[GlkMemoryStream alloc] initWithMemory: (unsigned char*)[data bytes]
											length: [data length]] autorelease];
}

- (byref NSObject<GlkStream>*) createWriteOnlyStream {
	return nil;
}

- (byref NSObject<GlkStream>*) createReadWriteStream {
	return nil;
}

- (void) deleteFile {
	// Do nothing
}

- (BOOL) fileExists {
	return YES;
}

- (BOOL) autoflushStream {
	return autoflush;
}

- (void) setAutoflush: (BOOL) newAutoflush {
	autoflush = newAutoflush;
}

@end
