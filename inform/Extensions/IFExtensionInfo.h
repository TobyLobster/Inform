//
//  IFExtensionInfo.h
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFSemVer.h"

NS_ASSUME_NONNULL_BEGIN

@interface IFExtensionInfo : NSObject

@property (atomic, copy)   NSString* displayName;
@property (atomic, copy, nullable) NSString* filepath;
@property (atomic, copy)   NSString* author;
/// The version (\c nil or empty if the extension has none)
@property (atomic, copy, nullable) NSString* version;
@property (atomic)         BOOL      isBuiltIn;

-(instancetype) init NS_UNAVAILABLE;

-(instancetype) initWithDisplayName: (NSString*) displayName
                 filepath: (nullable NSString*) filepath
                   author: (NSString*) author
                  version: (nullable NSString*) version
                isBuiltIn: (BOOL) isBuiltIn NS_DESIGNATED_INITIALIZER;

/// Remove leading "The ", "An ", or "A ", and trailing proviso (in brackets) from a display name to get title used for extension filename
+(NSString*) canonicalTitle:(NSString*) displayName;
@property (atomic, readonly, copy) NSString *safeVersion;
@property (atomic, readonly, copy) IFSemVer *semver;
-(BOOL) isEqual: (nullable id) other;

@end

NS_ASSUME_NONNULL_END
