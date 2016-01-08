//
//  ZoomBlorbFile.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jul 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZoomProtocol.h"

@interface ZoomBlorbFile : NSObject

// Testing files
+ (BOOL) dataIsBlorbFile: (NSData*) data;
+ (BOOL) fileContentsIsBlorb: (NSString*) filename;
+ (BOOL) zfileIsBlorb: (NSObject<ZFile>*) file;

// Initialisation
- (instancetype) initWithZFile: (NSObject<ZFile>*) file NS_DESIGNATED_INITIALIZER; // Designated initialiser
- (instancetype) initWithData: (NSData*) blorbFile;
- (instancetype) initWithContentsOfFile: (NSString*) filename;

// Cache control
- (void) removeAdaptiveImagesFromCache;

// Generic IFF data
- (NSArray*) chunksWithType: (NSString*) chunkType;
- (NSData*) dataForChunk: (id) chunk;
- (NSData*) dataForChunkWithType: (NSString*) chunkType;

// The resource index
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL parseResourceIndex;
- (BOOL) containsImageWithNumber: (int) num;

// Typed data
- (NSData*) imageDataWithNumber: (int) num;
- (NSData*) soundDataWithNumber: (int) num;

// Decoded data
- (NSImage*) imageWithNumber: (int) num;
- (NSSize) sizeForImageWithNumber: (int) num
					forPixmapSize: (NSSize) pixmapSize;
@end
