//
//  ZoomBlorbFile.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jul 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZoomProtocol.h"

@interface ZoomBlorbFile : NSObject {
	NSObject<ZFile>* file;
	
	NSString*       formID;
	unsigned int    formLength;

	NSMutableArray*		 iffBlocks;
	NSMutableDictionary* typesToBlocks;
	NSMutableDictionary* locationsToBlocks;
	
	NSMutableDictionary* resourceIndex;
	
	BOOL adaptive;
	NSMutableSet* adaptiveImages;
	NSData*       activePalette;
	
	NSSize stdSize;
	NSSize minSize;
	NSSize maxSize;
	NSMutableDictionary* resolution;
	
	NSMutableDictionary* cache;
	unsigned int maxCacheNum;
}

// Testing files
+ (BOOL) dataIsBlorbFile: (NSData*) data;
+ (BOOL) fileContentsIsBlorb: (NSString*) filename;
+ (BOOL) zfileIsBlorb: (NSObject<ZFile>*) file;

// Initialisation
- (id) initWithZFile: (NSObject<ZFile>*) file; // Designated initialiser
- (id) initWithData: (NSData*) blorbFile;
- (id) initWithContentsOfFile: (NSString*) filename;

// Cache control
- (void) removeAdaptiveImagesFromCache;

// Generic IFF data
- (NSArray*) chunksWithType: (NSString*) chunkType;
- (NSData*) dataForChunk: (id) chunk;
- (NSData*) dataForChunkWithType: (NSString*) chunkType;

// The resource index
- (BOOL) parseResourceIndex;
- (BOOL) containsImageWithNumber: (int) num;

// Typed data
- (NSData*) imageDataWithNumber: (int) num;
- (NSData*) soundDataWithNumber: (int) num;

// Decoded data
- (NSImage*) imageWithNumber: (int) num;
- (NSSize) sizeForImageWithNumber: (int) num
					forPixmapSize: (NSSize) pixmapSize;
@end
