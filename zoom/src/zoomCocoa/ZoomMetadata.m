//
//  ZoomMetadata.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomMetadata.h"
#import "ZoomAppDelegate.h"

#include "ifmetabase.h"
#include "ifmetaxml.h"

#define ReportErrors

NSString* ZoomMetadataWillDestroyStory = @"ZoomMetadataWillDestroyStory";

@implementation ZoomMetadata

// = Initialisation, etc =

- (id) init {
	self = [super init];
	
	if (self) {
		metadata = IFMB_Create();
		dataLock = [[NSLock alloc] init];
	}
	
	return self;
}

- (id) initWithData: (NSData*) xmlData
		   filename: (NSString*) fname {
	self = [super init];
	
	if (self) {
		filename = [fname copy];
		
		metadata = IFMB_Create();
		IF_ReadIfiction(metadata, [xmlData bytes], [xmlData length]);
		dataLock = [[NSLock alloc] init];
		
#if 0
		if (metadata->numberOfErrors > 0) {
			NSLog(@"ZoomMetadata: encountered errors in file %@", filename!=nil?[filename lastPathComponent]:@"(memory)");
			
			int x;
			for (x=0; x<metadata->numberOfErrors; x++) {
				NSLog(@"ZoomMetadata: %@ at line %i: %s",
					  metadata->error[x].severity==IFMDErrorWarning?@"Warning":@"Error",
					  metadata->error[x].lineNumber,
					  metadata->error[x].moreText);
			}
		}
#endif
		
#ifdef IFMD_ALLOW_TESTING
		// Test, if available
		IFMD_testrepository(metadata);
#endif
	}
	
	return self;
}

- (id) initWithContentsOfFile: (NSString*) fname {
	return [self initWithData: [NSData dataWithContentsOfFile: fname]
					 filename: fname];
}

- (id) initWithData: (NSData*) xmlData {
	return [self initWithData: xmlData
					 filename: nil];
}

- (void) dealloc {
	IFMB_Free(metadata);
	[dataLock release];
	
	if (filename) [filename release];
	
	[super dealloc];
}

// = Locking =

- (void) lock {
	[dataLock lock];
}

- (void) unlock {
	[dataLock unlock];
}

// = Finding information =

- (BOOL) containsStoryWithIdent: (ZoomStoryID*) ident {
	if (ident == nil || [ident ident] == NULL) return NO;
	return IFMB_ContainsStoryWithId(metadata, [ident ident]);
}

- (ZoomStory*) findOrCreateStory: (ZoomStoryID*) ident {
	IFStory story;
	
	if ([ident ident] == nil) return nil;
	
	[dataLock lock];
	
	story = IFMB_GetStoryWithId(metadata, [ident ident]);
	
	if (story) {
		ZoomStory* res = [[ZoomStory alloc] initWithStory: story
												 metadata: self];
		
		[dataLock unlock];
		return [res autorelease];
	} else {
		[dataLock unlock];
		return nil;
	}
}

- (NSArray*) stories {
	NSMutableArray* res = [NSMutableArray array];
	
	IFStoryIterator iter;
	IFStory story;
	for (iter=IFMB_GetStoryIterator(metadata); story=IFMB_NextStory(iter);) {
		ZoomStory* zStory = [[ZoomStory alloc] initWithStory: story
													metadata: self];
		
		[res addObject: zStory];
		[zStory release];
	}
	IFMB_FreeStoryIterator(iter);
	
	return res;
}

// = Storing information =

- (void) removeStoryWithIdent: (ZoomStoryID*) ident {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomMetadataWillDestroyStory
														object: self
													  userInfo: [NSDictionary dictionaryWithObjectsAndKeys: 
														  ident, @"Ident",
														  nil]];
	
	[dataLock lock];
	
	IFMB_RemoveStoryWithId(metadata, [ident ident]);
	
#ifdef IFMD_ALLOW_TESTING
	// Test, if available
	IFMD_testrepository(metadata);
#endif
	
	[dataLock unlock];
}

- (void) copyStory: (ZoomStory*) story {
	IFMB_CopyStory(metadata, [story story], NULL);
}

- (void) copyStory: (ZoomStory*) story
			  toId: (ZoomStoryID*) copyID {
	IFMB_CopyStory(metadata, [story story], [copyID ident]);
}
	

// = Saving the file =

static int dataWrite(const char* bytes, int length, void* userData) {
	NSMutableData* data = userData;
	[data appendBytes: bytes
			   length: length];
	return 0;
}

- (NSData*) xmlData {
	[dataLock lock];
	NSMutableData* res = [[NSMutableData alloc] init];
	
	IF_WriteIfiction(metadata, dataWrite, res);
	
	[dataLock unlock];
	return [res autorelease];
}

- (BOOL) writeToFile: (NSString*)path
		  atomically: (BOOL)flag {
	return [[self xmlData] writeToFile: path atomically: flag];
}

- (BOOL) writeToDefaultFile {
	// The app delegate may not be the best place for this routine... Maybe a function somewhere
	// would be better?
	NSString* configDir = [[NSApp delegate] zoomConfigDirectory];
	
	return [self writeToFile: [configDir stringByAppendingPathComponent: @"metadata.iFiction"]
				  atomically: YES];
}

// = Errors =
- (NSArray*) errors {
#if 0
	int x;
	NSMutableArray* array = [NSMutableArray array];
	
	for (x=0; x<metadata->numberOfErrors; x++) {
		if (metadata->error[x].severity == IFMDErrorFatal) {
			NSString* errorName = @"";
			
			switch (metadata->error[x].type) {
				case IFMDErrorProgrammerIsASpoon:
					errorName = @"Programmer is a spoon";
					break;
					
				case IFMDErrorXMLError:
					errorName = @"XML parsing error";
					break;
					
				case IFMDErrorNotXML:
					errorName = @"File is not in XML format";
					break;
					
				case IFMDErrorUnknownVersion:
					errorName = @"Unknown iFiction version number";
					break;
					
				case IFMDErrorUnknownTag:
					errorName = @"Invalid iFiction tag encountered in file";
					break;
					
				case IFMDErrorNotIFIndex:
					errorName = @"No index found";
					break;
					
				case IFMDErrorUnknownFormat:
					errorName = @"Unknown story format";
					break;
					
				case IFMDErrorMismatchedFormats:
					errorName = @"Story and identification data specify different formats";
					break;
					
				case IFMDErrorStoriesShareIDs:
					errorName = @"Two stories have the same ID";
					break;
					
				case IFMDErrorDuplicateID:
					errorName = @"One story contains the same ID twice";
					break;
			}
			
			[array addObject: [NSString stringWithFormat: errorName, metadata->error[x].moreText]];
		}
	}
	
	return array;
#else
	return [NSArray array];
#endif
}

@end
