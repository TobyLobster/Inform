//
//  ZoomStoryID.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <ZoomPlugIns/ifmetabase.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const ZoomStoryIDErrorDomain;
typedef NS_ERROR_ENUM(ZoomStoryIDErrorDomain, ZoomStoryIDError) {
	ZoomStoryIDErrorFileTooSmall,
	ZoomStoryIDErrorBadZCodeVersion,
	ZoomStoryIDErrorNoZCodeChunk,
	ZoomStoryIDErrorNoGlulxChunk,
	ZoomStoryIDErrorNoIdentGenerated
};

@interface ZoomStoryID : NSObject<NSCopying, NSSecureCoding>

+ (nullable ZoomStoryID*) idForFile: (NSString*) filename DEPRECATED_MSG_ATTRIBUTE("Use -idForURL: instead");
+ (nullable ZoomStoryID*) idForURL: (NSURL*) filename;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
- (nullable instancetype) initWithZCodeStory: (NSData*) gameData DEPRECATED_MSG_ATTRIBUTE("Use -initWithZCodeStory:error: instead") NS_SWIFT_UNAVAILABLE("");
- (nullable instancetype) initWithZCodeFile: (NSString*) zcodeFile DEPRECATED_MSG_ATTRIBUTE("Use -initWithZCodeFileAtURL:error: instead");
- (nullable instancetype) initWithGlulxFile: (NSString*) glulxFile DEPRECATED_MSG_ATTRIBUTE("Use -initWithGlulxFileAtURL:error: instead");
- (nullable instancetype) initWithData: (NSData*) genericGameData;
- (nullable instancetype) initWithData: (NSData*) genericGameData
								  type: (NSString*) type;
- (instancetype) initWithIdent: (IFID) ident;
- (instancetype) initWithUUID: (NSUUID*) uuid;
- (instancetype) initWithIdString: (NSString*) idString;
- (instancetype) initWithZcodeRelease: (int) release
							   serial: (const unsigned char*) serial
							 checksum: (int) checksum;

@property (readonly) IFID ident NS_RETURNS_INNER_POINTER;

- (nullable instancetype) initWithZCodeStory: (NSData*) gameData error: (NSError**) outError;
- (nullable instancetype) initWithZCodeFileAtURL: (NSURL*) zcodeFile error: (NSError**) outError;
- (nullable instancetype) initWithGlulxFileAtURL: (NSURL*) glulxFile error: (NSError**) outError;


- (nullable instancetype)initWithCoder:(NSCoder *)coder;

@end

//! Set to \c YES to prevent the plug-in manager from looking at plug-ins.
extern BOOL ZoomIsSpotlightIndexing;

NS_ASSUME_NONNULL_END
