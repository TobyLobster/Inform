//
//  GlkFileRef.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkFileRef.h"
#import "GlkFileStream.h"


@implementation GlkFileRef

#pragma mark - Initialisation

- (id) initWithPath: (NSURL*) path {
	self = [super init];
	
	if (self) {
		pathname = [[path URLByStandardizingPath] copy];
		temporary = NO;
		
#if defined(COCOAGLK_IPHONE)
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(applicationWillTerminate:)
													 name: UIApplicationWillTerminateNotification
												   object: [UIApplication sharedApplication]];
#else
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(applicationWillTerminate:)
													 name: NSApplicationWillTerminateNotification
												   object: NSApp];
#endif
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	if (temporary) {
		NSLog(@"Removing temporary file: %@", pathname);

		// Delete any temporary files when deallocated
		[[NSFileManager defaultManager] removeItemAtURL: pathname 
                                                  error: nil];
    }
}

- (void) applicationWillTerminate: (NSNotification*) not {
	if (temporary) {
		NSLog(@"Removing temporary file: %@", pathname);
		
		// Also delete any temporary files when the application terminates
		[[NSFileManager defaultManager] removeItemAtURL: pathname
                                                  error: nil];
	}
}

#pragma mark - Temporaryness

@synthesize temporary;

#pragma mark - The fileref protocol

- (byref id<GlkStream>) createReadOnlyStream {
	GlkFileStream* stream = [[GlkFileStream alloc] initForReadingFromFileURL: pathname];
	
	return stream;
}

- (byref id<GlkStream>) createWriteOnlyStream; {
	GlkFileStream* stream = [[GlkFileStream alloc] initForWritingToFileURL: pathname];
	
	return stream;
}

- (byref id<GlkStream>) createReadWriteStream {
	GlkFileStream* stream = [[GlkFileStream alloc] initForReadWriteWithFileURL: pathname];
	
	return stream;
}

- (void) deleteFile {
	[[NSFileManager defaultManager] removeItemAtURL: pathname error: nil];
}

- (BOOL) fileExists {
    if (![pathname isFileURL]) return NO;
	return [[NSFileManager defaultManager] fileExistsAtPath: [pathname path]];
}

@synthesize autoflushStream = autoflush;

@end
