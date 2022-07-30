//
//  IFGlkResources.h
//  Inform
//
//  Created by Andrew Hunter on 29/08/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlkView/GlkView.h>

@class IFProject;

///
/// Class that retrieves Glk resources from the materials directory
///
@interface IFGlkResources : NSObject<GlkImageSource>

- (instancetype)init NS_UNAVAILABLE;

/// Initialise this resource file to get image resources from the specified project
- (instancetype) initWithProject: (IFProject*) project NS_DESIGNATED_INITIALIZER;

@end
