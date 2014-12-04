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

//
// Objective-C interface to the babel command line tool
//
@interface ZoomBabel : NSObject {
	float timeout;											// Maximum time to block for before giving up
	
	NSString* filename;										// The file that needs identifying
	NSTask* babelTask;										// The babel task
	NSPipe* babelStdOut;									// The standard output from the babel task
	
	NSData* metadata;										// The raw XML metadata
	NSData* babelImage;										// The raw cover image
	
	NSMutableArray* waitingForTask;							// Tasks waiting for babel to finish

	NSTask* ifidTask;										// Task waiting for the IFID
	NSPipe* ifidStdOut;										// Stdout from the ifid task
	ZoomStoryID* storyID;									// Story ID that we last read
}

// = Initialisation =

- (id) initWithFilename: (NSString*) story;					// Initialise this object with the specified story (metadata and image extraction will start immediately)

// = Raw reading =

- (void) setTaskTimeout: (float) seconds;					// Sets the maximum time to wait for the babel command to respond when blocking (default is 0.2 seconds)

- (NSData*) rawMetadata;									// Retrieves a raw XML metadata record (or nil)
- (NSData*) rawCoverImage;									// Retrieves the raw cover image data (or nil)

// = Interpreted reading =

- (ZoomStoryID*) storyID;									// Requests the IFID for the story file
- (ZoomStory*) metadata;									// Retrieves the metadata for this file
- (NSImage*) coverImage;									// Retrieves the cover image for this file

@end
