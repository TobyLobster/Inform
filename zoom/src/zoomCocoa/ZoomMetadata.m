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
#include "ifmetadata.h"
#include "ifmetaxml.h"

#define ReportErrors

NSString* const ZoomMetadataWillDestroyStory = @"ZoomMetadataWillDestroyStory";

NSErrorDomain const ZoomMetadataErrorDomain = @"uk.org.logicalshift.ZoomPlugIns.errors";

#define ZoomLocalizedStringWithDefaultValue(key, val, comment) \
	NSLocalizedStringWithDefaultValue(key, @"ZoomErrors", [NSBundle bundleForClass: [ZoomMetadata class]], val, comment)

@interface ZoomMetadata ()

- (instancetype) initWithData: (NSData*) xmlData
					  fileURL: (NSURL*) fname
						error: (NSError**) error NS_DESIGNATED_INITIALIZER;

@end

@implementation ZoomMetadata {
	NSURL* filename;
	IFMetabase metadata;
	
	NSLock* dataLock;
}

#pragma mark - Initialisation, etc

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[NSError setUserInfoValueProviderForDomain:ZoomMetadataErrorDomain provider:^id _Nullable(NSError * _Nonnull err, NSErrorUserInfoKey  _Nonnull userInfoKey) {
			switch ((ZoomMetadataError)err.code) {
				case ZoomMetadataErrorProgrammerIsASpoon:
					if ([userInfoKey isEqualToString:NSDebugDescriptionErrorKey]) {
						return @"Programmer is a spoon";
					} else if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return ZoomLocalizedStringWithDefaultValue(@"ZoomMetadataError Programmer Is A Spoon", @"Programmer is a spoon", @"Programmer is a spoon");
					}
					break;
					
				case ZoomMetadataErrorXML:
					if ([userInfoKey isEqualToString:NSDebugDescriptionErrorKey]) {
						return @"XML parsing error";
					} else if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return ZoomLocalizedStringWithDefaultValue(@"ZoomMetadataError XML", @"XML parsing error", @"XML parsing error");
					}
					break;
					
				case ZoomMetadataErrorNotXML:
					if ([userInfoKey isEqualToString:NSDebugDescriptionErrorKey]) {
						return @"File is not in XML format";
					} else if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return ZoomLocalizedStringWithDefaultValue(@"ZoomMetadataError Not XML", @"File is not in XML format", @"File is not in XML format");
					}
					break;
					
				case ZoomMetadataErrorUnknownVersion:
					if ([userInfoKey isEqualToString:NSDebugDescriptionErrorKey]) {
						return @"Unknown iFiction version number";
					} else if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return ZoomLocalizedStringWithDefaultValue(@"ZoomMetadataError Unknown Version", @"Unknown iFiction version number", @"Unknown iFiction version number");
					}
					break;
					
				case ZoomMetadataErrorUnknownTag:
					if ([userInfoKey isEqualToString:NSDebugDescriptionErrorKey]) {
						return @"Invalid iFiction tag encountered in file";
					} else if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return ZoomLocalizedStringWithDefaultValue(@"ZoomMetadataError Unknown Tag", @"Invalid iFiction tag encountered in file", @"Invalid iFiction tag encountered in file");
					}
					break;
					
				case ZoomMetadataErrorNotIFIndex:
					if ([userInfoKey isEqualToString:NSDebugDescriptionErrorKey]) {
						return @"No index found";
					} else if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return ZoomLocalizedStringWithDefaultValue(@"ZoomMetadataError Not IF Index", @"No index found", @"No index found");
					}
					break;
					
				case ZoomMetadataErrorUnknownFormat:
					if ([userInfoKey isEqualToString:NSDebugDescriptionErrorKey]) {
						return @"Unknown story format";
					} else if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return ZoomLocalizedStringWithDefaultValue(@"ZoomMetadataError Unknown Format", @"Unknown story format", @"Unknown story format");
					}
					break;
					
				case ZoomMetadataErrorMismatchedFormats:
					if ([userInfoKey isEqualToString:NSDebugDescriptionErrorKey]) {
						return @"Story and identification data specify different formats";
					} else if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return ZoomLocalizedStringWithDefaultValue(@"ZoomMetadataError Mismatched Formats", @"Story and identification data specify different formats", @"Story and identification data specify different formats");
					}
					break;
					
				case ZoomMetadataErrorStoriesShareIDs:
					if ([userInfoKey isEqualToString:NSDebugDescriptionErrorKey]) {
						return @"Two stories have the same ID";
					} else if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return ZoomLocalizedStringWithDefaultValue(@"ZoomMetadataError Stories Share IDs", @"Two stories have the same ID", @"Two stories have the same ID");
					}
					break;
					
				case ZoomMetadataErrorDuplicateID:
					if ([userInfoKey isEqualToString:NSDebugDescriptionErrorKey]) {
						return @"One story contains the same ID twice";
					} else if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return ZoomLocalizedStringWithDefaultValue(@"ZoomMetadataError Duplicate ID", @"One story contains the same ID twice", @"One story contains the same ID twice");
					}
					break;
			}
			return nil;
		}];
	});
}

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
	return [self initWithData: xmlData
					  fileURL: [NSURL fileURLWithPath:fname]
						error: NULL];
}

- (instancetype) initWithData: (NSData*) xmlData
					  fileURL: (NSURL*) fname
						error: (NSError**) error {
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
	return [self initWithContentsOfURL: [NSURL fileURLWithPath: fname]
								 error: NULL];
}

- (instancetype) initWithContentsOfURL: (NSURL*) filename error: (NSError**) outError {
	NSData *data = [NSData dataWithContentsOfURL: filename
										 options: NSDataReadingMappedIfSafe
										   error: outError];
	if (!data) {
		return nil;
	}
	return [self initWithData: data
					  fileURL: filename
						error: outError];
}

- (id) initWithData: (NSData*) xmlData
			  error: (NSError**) outError {
	return [self initWithData: xmlData
					  fileURL: nil
						error: outError];
}

- (id) initWithData: (NSData*) xmlData {
	return [self initWithData: xmlData
					  fileURL: nil
						error: NULL];
}

- (void) dealloc {
	IFMB_Free(metadata);
}

#pragma mark - Locking

- (void) lock {
	[dataLock lock];
}

- (void) unlock {
	[dataLock unlock];
}

#pragma mark - Finding information

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
		return res;
	} else {
		[dataLock unlock];
		return nil;
	}
}

- (NSArray*) stories {
	NSMutableArray* res = [NSMutableArray array];
	
	IFStoryIterator iter;
	IFStory story;
	for ((iter=IFMB_GetStoryIterator(metadata)); (story=IFMB_NextStory(iter));) {
		ZoomStory* zStory = [[ZoomStory alloc] initWithStory: story
													metadata: self];
		
		[res addObject: zStory];
	}
	IFMB_FreeStoryIterator(iter);
	
	return res;
}

#pragma mark - Storing information

- (void) removeStoryWithIdent: (ZoomStoryID*) ident {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomMetadataWillDestroyStory
														object: self
													  userInfo: @{@"Ident": ident}];
	
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
	

#pragma mark - Saving the file

static int dataWrite(const char* bytes, int length, void* userData) {
	NSMutableData* data = (__bridge NSMutableData *)(userData);
	[data appendBytes: bytes
			   length: length];
	return 0;
}

- (NSData*) xmlData {
	[dataLock lock];
	NSMutableData* res = [[NSMutableData alloc] init];
	
	IF_WriteIfiction(metadata, dataWrite, (__bridge void *)(res));
	
	[dataLock unlock];
	return res;
}

- (BOOL) writeToFile: (NSString*)path
		  atomically: (BOOL)flag {
	return [self writeToURL: [NSURL fileURLWithPath: path]
				 atomically: flag
					  error: NULL];
}

- (BOOL)    writeToURL: (NSURL*)path
			atomically: (BOOL)flag
				 error: (NSError**)error {
	return [[self xmlData] writeToURL: path
							  options: (flag ? NSDataWritingAtomic : 0)
								error: error];
}

- (BOOL) writeToDefaultFile {
	return [self writeToDefaultFileWithError: NULL];
}

- (BOOL) writeToDefaultFileWithError:(NSError *__autoreleasing *)outError {
	// The app delegate may not be the best place for this routine... Maybe a function somewhere
	// would be better?
	NSString* configDir = [(ZoomAppDelegate*)[NSApp delegate] zoomConfigDirectory];
	NSURL *configURL = [NSURL fileURLWithPath: configDir isDirectory: YES];
	configURL = [configURL URLByAppendingPathComponent: @"metadata.iFiction" isDirectory: NO];
	
	return [self writeToURL: configURL
				 atomically: YES
					  error: outError];
}

#pragma mark - Errors
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
