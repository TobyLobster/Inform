//
//  ZoomBlorbFile.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jul 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ZoomView/ZoomProtocol.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const ZoomBlorbErrorDomain;
typedef NS_ERROR_ENUM(ZoomBlorbErrorDomain, ZoomBlorbError) {
	ZoomBlorbErrorTooSmall,
	ZoomBlorbErrorNoFORMBlock
};

@interface ZoomBlorbFile : NSObject

// Testing files
+ (BOOL) dataIsBlorbFile: (NSData*) data;
+ (BOOL) fileContentsIsBlorb: (NSString*) filename DEPRECATED_MSG_ATTRIBUTE("Use +URLContentsAreBlorb: instead");
+ (BOOL) URLContentsAreBlorb: (NSURL*) filename;
+ (BOOL) zfileIsBlorb: (id<ZFile>) file;

// Initialisation
- (instancetype)init UNAVAILABLE_ATTRIBUTE;
/// Designated initialiser
- (nullable instancetype) initWithZFile: (id<ZFile>) file error: (NSError**) outError NS_DESIGNATED_INITIALIZER;
- (nullable instancetype) initWithZFile: (id<ZFile>) file DEPRECATED_MSG_ATTRIBUTE("Use -initWithZFile:error: instead") NS_SWIFT_UNAVAILABLE("");
- (nullable instancetype) initWithData: (NSData*) blorbFile error: (NSError**) outError;
- (nullable instancetype) initWithData: (NSData*) blorbFile DEPRECATED_MSG_ATTRIBUTE("Use -initWithData:error: instead") NS_SWIFT_UNAVAILABLE("");
- (nullable instancetype) initWithContentsOfFile: (NSString*) filename DEPRECATED_MSG_ATTRIBUTE("Use -initWithContentsOfURL:error: instead");
- (nullable instancetype) initWithContentsOfURL: (NSURL*) filename error: (NSError**) outError;

// Cache control
- (void) removeAdaptiveImagesFromCache;

// Generic IFF data
- (nullable NSArray<NSDictionary<NSString*,id>*>*) chunksWithType: (NSString*) chunkType;
- (nullable NSData*) dataForChunk: (NSDictionary<NSString*,id>*) chunk;
- (nullable NSData*) dataForChunkWithType: (NSString*) chunkType;

// The resource index
- (BOOL) parseResourceIndex;
- (BOOL) containsImageWithNumber: (int) num;

// Typed data
- (nullable NSData*) imageDataWithNumber: (int) num;
- (nullable NSData*) soundDataWithNumber: (int) num;

// Decoded data
- (nullable NSImage*) imageWithNumber: (int) num;
- (NSSize) sizeForImageWithNumber: (int) num
					forPixmapSize: (NSSize) pixmapSize;
@end

NS_ASSUME_NONNULL_END
