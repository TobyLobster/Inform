//
//  ZoomSignPost.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 28/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ZoomStoryID;

///
/// Class that deals with understanding IFDB signpost files.
///
@interface ZoomSignPost : NSObject<NSXMLParserDelegate>

#pragma mark - Initialising

//! Parses the specified signpost data
- (nullable instancetype) initWithData: (NSData*) data;
//! Replaces the data stored in this signpost with the specified data
- (BOOL) parseData: (NSData*) data;

#pragma mark - Getting signpost data

//! The IDs associated with this signpost
@property (readonly, copy) NSArray<ZoomStoryID*> *ifids;
//! The display name of the interpreter (the interpreter system name)
@property (readonly, copy, nullable) NSString *interpreterDisplayName;
//! The URL of the interpreter update page
@property (readonly, copy, nullable) NSURL *interpreterURL;
//! The requested interpreter version
@property (readonly, copy, nullable) NSString *interpreterVersion;
//! The requested plugin version
@property (readonly, copy, nullable) NSString *pluginVersion;
//! The download URL for the game
@property (readonly, copy, nullable) NSURL *downloadURL;
//! The error contained in this signpost (or nil)
@property (readonly, copy, nullable) NSString *errorMessage;

//! Returns a serialized NSData object for this signpost (can be passed back to initWithData: to reload the signpost later)
- (NSData*) data;

@end

NS_ASSUME_NONNULL_END
