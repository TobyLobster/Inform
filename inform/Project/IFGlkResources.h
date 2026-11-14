//
//  IFGlkResources.h
//  Inform
//
//  Created by Andrew Hunter on 29/08/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlkView/GlkView.h>

NS_ASSUME_NONNULL_BEGIN

@class IFProject;

///
/// Class that retrieves Glk resources from the materials directory, for a story played without a Blorb
///
NS_SWIFT_UI_ACTOR
@interface IFGlkResources : NSObject<GlkImageSource, GlkSoundSource>

- (instancetype)init NS_UNAVAILABLE;

/// Initialise this resource file to get image and sound resources from the specified project
- (instancetype) initWithProject: (IFProject*) project NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
