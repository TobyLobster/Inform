//
//  ZoomBabel.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 10/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomBabel.h"
#import "ZoomMetadata.h"

static NSString* babelFolder = nil;
static NSLock* babelLock;
static NSMutableDictionary* babelCache = nil;

@interface ZoomBabel()

- (void) babelTaskFinished: (NSNotification*) not;
- (void) handleBabelTaskFinished;

@end

@implementation ZoomBabel

+ (void) initialize {
	babelLock = [[NSLock alloc] init];
	babelCache = [[NSMutableDictionary alloc] init];
}

+ (NSString*) babelFolder {
	// Retrieves the folder to run the babel command in
	[babelLock lock];
	
	if (babelFolder == nil) {
		// Work out a folder to store our temporary files in
		NSString* tempDir = NSTemporaryDirectory();
		NSString* dirID = [NSString stringWithFormat: @"Zoom-Babel-%i", getpid()];
		
		babelFolder = [tempDir stringByAppendingPathComponent: dirID];
	}

	// Create the directory if necessary
	BOOL isDir = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath: babelFolder
											  isDirectory: &isDir]) {
		[[NSFileManager defaultManager] createDirectoryAtPath: babelFolder
								  withIntermediateDirectories: NO
												   attributes: nil
														error: NULL];
		isDir = YES;
	}
	
	[babelLock unlock];
	
	if (!isDir) return nil;
	return babelFolder;
}

#pragma mark - Initialisation

- (id) init {
	self = [super init];
	return nil;
}

- (id) initWithFilename: (NSString*) story {
	// Initialise this object with the specified story (metadata and image extraction will start immediately)
	self = [super init];
	
	[babelLock lock];
	
	// Try to find this story in the cache
	ZoomBabel* cachedVersion = [babelCache objectForKey: story];
	if (cachedVersion != nil) {
		// Use the cached version instead if possible
		[babelLock unlock];
		return cachedVersion;
	}
	
	// Empty the cache if it's too full (fairly dumb, but works for the expected usage patterns)
	if ([babelCache count] > 10) {
		babelCache = [[NSMutableDictionary alloc] init];
	}
	
	// Store this object in the cache
	[babelCache setObject: self
				   forKey: story];
	
	[babelLock unlock];

	if (self) {
		// Default timeout is 0.2 seconds
		timeout = 0.2;
		
		// Remember the file that we're reading
		filename = [story copy];
		
		waitingForTask = [[NSMutableArray alloc] init];
		
		// Start the babel task
		NSString* babelTaskFolder = [ZoomBabel babelFolder];
		if (babelTaskFolder != nil) {
			NSString* babelPath = [[NSBundle bundleForClass: [self class]] pathForResource: @"babel"
																					ofType: nil]; 
			
			babelTask = [[NSTask alloc] init];
			babelStdOut = [[NSPipe alloc] init];
			
			[babelTask setCurrentDirectoryPath: babelTaskFolder];
			[babelTask setLaunchPath: babelPath];
			[babelTask setStandardOutput: [babelStdOut fileHandleForWriting]];
			
			[babelTask setArguments: @[@"-fish", filename]];
			
			[[NSNotificationCenter defaultCenter] addObserver: self
													 selector: @selector(babelTaskFinished:)
														 name: NSTaskDidTerminateNotification
													   object: babelTask];
			
			[babelTask launch];
		}
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	if (babelTask) {
		[babelTask terminate];
		[babelTask waitUntilExit];

		[self babelTaskFinished: nil];
		
		babelTask = nil;
	}
	
	if (ifidTask) {
		[ifidTask terminate];
		ifidTask = nil;
	}
}

#pragma mark - Raw reading

- (void) waitForBabel {
	BOOL mustWait = NO;
	
	[babelLock lock];
	mustWait = babelTask != nil || ifidTask != nil;
	[babelLock unlock];
	
	if (mustWait) {
		// Remember that this runloop is waiting for a babel task to finish
		[babelLock lock];
		
		NSRunLoop* rl = [NSRunLoop currentRunLoop];
		//NSDate* now = [NSDate date];
		NSDate* terminate = [NSDate dateWithTimeIntervalSinceNow: timeout];
		
		[waitingForTask addObject: rl];
		
		[babelLock unlock];
		
		while (((babelTask && [babelTask isRunning])
				|| (ifidTask && [ifidTask isRunning]))
			   && [[NSDate date] compare: terminate] == NSOrderedAscending) {
			// Wait for events from the runloop (poll for the task ending, because the task finished notification fails to arrive while in event tracking mode)
			[rl runMode: NSEventTrackingRunLoopMode
			 beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.03]];
		}
		
		[waitingForTask removeObjectIdenticalTo: rl];
		
		// Kill the task if it has failed to complete
		[babelLock lock];
		if ([babelTask isRunning]) {
			[babelTask terminate];
		} else if (babelTask != nil) {
			[self handleBabelTaskFinished];
		}
		[babelLock unlock];
	}
	
}

@synthesize taskTimeout=timeout;

- (NSData*) rawMetadata {
	[self waitForBabel];
	
	return metadata;
}

- (NSData*) rawCoverImage {
	[self waitForBabel];
	
	return babelImage;
}

#pragma mark - Interpreted reading

- (ZoomStory*) metadata {
	// Get the metadata
	NSData* storyData = [self rawMetadata];
	
	// If non-nil, then extract the first ifiction record
	if (storyData != nil) {
		ZoomMetadata* storyMetadata = [[ZoomMetadata alloc] initWithData: storyData error: NULL];
		if (storyMetadata != nil) {
			NSArray* stories = [storyMetadata stories];
			if ([stories count] >= 1) {
				return [stories objectAtIndex: 0];
			}
		}
	}
	
	return nil;
}

- (NSImage*) coverImage {
	// Get the image data
	NSData* imageData = [self rawCoverImage];
	
	// If non-nil, create a new image
	if (imageData != nil) {
		return [[NSImage alloc] initWithData: imageData];
	}
	
	return nil;
}

#pragma mark - Story ID

- (ZoomStoryID*) storyID {
	if (!storyID) {
		// Try to read the story ID via babel
		NSString* babelTaskFolder = [ZoomBabel babelFolder];
		if (babelTaskFolder != nil && !ifidTask) {
			[babelLock lock];
			
			NSString* babelPath = [[NSBundle bundleForClass: [self class]] pathForResource: @"babel"
																					ofType: nil]; 
			
			ifidTask = [[NSTask alloc] init];
			ifidStdOut = [[NSPipe alloc] init];
			
			[ifidTask setCurrentDirectoryPath: babelTaskFolder];
			[ifidTask setLaunchPath: babelPath];
			[ifidTask setStandardOutput: [ifidStdOut fileHandleForWriting]];
			
			[ifidTask setArguments: @[@"-ifid", filename]];
			
			[[NSNotificationCenter defaultCenter] addObserver: self
													 selector: @selector(ifidTaskFinished:)
														 name: NSTaskDidTerminateNotification
													   object: babelTask];
			
			[ifidTask launch];

			[babelLock unlock];
		}
		
		[self waitForBabel];
	}
	
	return storyID;
}

#pragma mark - Notifications

- (NSArray*) filesFromBabelOutput: (NSString*) output {
	NSArray* lines = [output componentsSeparatedByString: @"\n"];
	NSMutableArray* filenames = [NSMutableArray array];
	
	for (NSString* line in lines) {
		// File lines match the pattern 'Extracted <x>'
		if ([line length] < 11) continue;
		if ([[line substringToIndex: 10] isEqualToString: @"Extracted "]) {
			[filenames addObject: [line substringFromIndex: 10]];
		}
	}
	
	return [filenames copy];
}

- (NSString*) fixFile: (NSString*) file {
	// Image files have the (size) suffix in the output from babel: remove this, as we don't care
	if ([file length] <= 0) return file;
	if ([file characterAtIndex: [file length] - 1] == ')') {
		NSInteger pos = [file length]-1;
		while (pos >= 0 && [file characterAtIndex: pos] != '(') {
			if ([file characterAtIndex: pos] == '.') return file;
			pos--;
		}
		
		if (pos <= 0) return file;
		file = [file substringToIndex: pos-1];
	}
	
	return file;
}

- (void) handleBabelTaskFinished {
	// (Actually perform finishing the babel task without acquiring the lock)
	// The babel task has finished...
	NSString* dir = [babelTask currentDirectoryPath];
	
	// Get the output
	[[babelStdOut fileHandleForWriting] closeFile];
	
	NSData* output = [[babelStdOut fileHandleForReading] readDataToEndOfFile];
	NSString* outputString = [[NSString alloc] initWithData: output encoding: NSUTF8StringEncoding];
	NSLog(@"Babel> %@", outputString);
	
	NSArray* files = [self filesFromBabelOutput: outputString];
	
	// Check the return code
	if ([babelTask terminationStatus] == 0) {
		// Read any files the babel task extracted
		for (__strong NSString* file in files) {
			// Image files have the (size) suffix in the output from babel: remove this, as we don't care
			file = [self fixFile: file];
			
			// Get the full path
			NSString* fullPath = [dir stringByAppendingPathComponent: file];
			NSString* extension = [[fullPath pathExtension] lowercaseString];
			
			if (![[NSFileManager defaultManager] fileExistsAtPath: fullPath]) {
				continue;
			}
			
			// Check for known extensions
			if ([extension isEqualToString: @"ifiction"]) {
				// This is an iFiction record
				metadata = [NSData dataWithContentsOfFile: fullPath];
			} else if ([extension isEqualToString: @"jpg"]
					   || [extension isEqualToString: @"jpeg"]
					   || [extension isEqualToString: @"png"]
					   || [extension isEqualToString: @"gif"]
					   || [extension isEqualToString: @"tif"]
					   || [extension isEqualToString: @"tiff"]) {
				// This is an image file
				babelImage = [NSData dataWithContentsOfFile: fullPath];
			}
		}
	}
	
	// Delete any files the babel task extracted
	for (NSString* file in files) {
		NSString* fullPath = [dir stringByAppendingPathComponent: [self fixFile: file]];
		if (![[NSFileManager defaultManager] fileExistsAtPath: fullPath]) {
			continue;
		}
		[[NSFileManager defaultManager] removeItemAtPath: fullPath
												   error: NULL];
	}
	
	// Finish up the task
	babelTask = nil;
	babelStdOut = nil;
}
	
- (void) babelTaskFinished: (NSNotification*) not {
	[babelLock lock];
	[self handleBabelTaskFinished];
	[babelLock unlock];
	
#if 0
	// Inform any runloops waiting on the task that they can stop now... Oops, not thread safe
	// FIXME: we want to be able to do this in case we want to read metadata on another thread (eg on Zoom startup)
	// as otherwise we'll wait for the full timeout time for each file
	NSEnumerator* rlEnumerator = [waitingForTask objectEnumerator];
	NSRunLoop* rl;
	while (rl = [rlEnumerator nextObject]) {
		[rl performSelector: @selector(threadNotifyTaskFinished)
					 target: self
				   argument: nil
					  order: 32
					  modes: [NSArray arrayWithObjects: 
						  NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil]];
	}
#endif
}


- (void) ifidTaskFinished: (NSNotification*) not {
	[babelLock lock];
	
	// Get the output
	[[ifidStdOut fileHandleForWriting] closeFile];
	
	NSData* output = [[ifidStdOut fileHandleForReading] readDataToEndOfFile];
	NSString* outputString = [[NSString alloc] initWithData: output encoding: NSUTF8StringEncoding];
	NSLog(@"Babel> %@", outputString);
	
	// Check the return code
	if ([babelTask terminationStatus] == 0) {
		NSArray* lines = [outputString componentsSeparatedByString: @"\n"];
		for (__strong NSString* line in lines) {
			// IFIDs must be 3 characters long
			if ([line length] < 3) continue;
			
			// If the line begins with IFID: then strip it out
			if ([line hasPrefix: @"IFID: "]) {
				line = [line substringFromIndex: 6];
				storyID = [[ZoomStoryID alloc] initWithIdString: line];
				break;
			}
		}
	}
		
	[babelLock unlock];
}

@end
