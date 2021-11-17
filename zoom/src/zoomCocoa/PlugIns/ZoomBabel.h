//
//  ZoomBabel.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 10/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomPlugIns/ZoomStory.h>
#import <ZoomPlugIns/ZoomStoryID.h>

//!
//! Objective-C interface to the babel command line tool
//!
@interface ZoomBabel : NSObject {
	//! Maximum time to block for before giving up
	NSTimeInterval timeout;
	
	//! The file that needs identifying
	NSString* filename;
	//! The babel task
	NSTask* babelTask;
	//! The standard output from the babel task
	NSPipe* babelStdOut;
	
	//! The raw XML metadata
	NSData* metadata;
	//! The raw cover image
	NSData* babelImage;
	
	//! Tasks waiting for babel to finish
	NSMutableArray* waitingForTask;

	//! Task waiting for the IFID
	NSTask* ifidTask;
	//! Stdout from the ifid task
	NSPipe* ifidStdOut;
	//! Story ID that we last read
	ZoomStoryID* storyID;
}

#pragma mark - Initialisation

//! Initialise this object with the specified story (metadata and image extraction will start immediately)
- (id) initWithFilename: (NSString*) story;

#pragma mark - Raw reading

@property NSTimeInterval taskTimeout;
//! Sets the maximum time to wait for the babel command to respond when blocking (default is 0.2 seconds)
- (void) setTaskTimeout: (NSTimeInterval) seconds;

//! Retrieves a raw XML metadata record (or nil)
- (NSData*) rawMetadata;
//! Retrieves the raw cover image data (or nil)
- (NSData*) rawCoverImage;

#pragma mark - Interpreted reading

//! Requests the IFID for the story file
- (ZoomStoryID*) storyID;
//! Retrieves the metadata for this file
- (ZoomStory*) metadata;
//! Retrieves the cover image for this file
- (NSImage*) coverImage;

@end
