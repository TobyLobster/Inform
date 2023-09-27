//
//  IFNewInform7Extension.h
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFNewProjectProtocol.h"


@class IFProject;
@class IFNewInform7ExtensionView;

///
/// Project type that makes it possible to create new Natural Inform extensions directories
///
@interface IFNewInform7ExtensionFile : NSObject<IFNewProjectProtocol>

- (instancetype) initWithProject: (IFProject*) theProject;

@end

/// (This class name sounds suspiciously likes a free sample from one of those spams...)
@interface IFNewInform7ExtensionView : NSObject<IFNewProjectSetupView>

- (void) setupControls;
@property (atomic, readonly, copy) NSString *authorName;
@property (atomic, readonly, copy) NSString *extensionName;
- (void) setInitialFocus: (NSWindow*) window;

@end
