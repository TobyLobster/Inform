//
//  IFNewInform7Extension.h
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFNewProjectProtocol.h"

//
// Project type that makes it possible to create new Natural Inform extensions directories
//
@class IFNewInform7ExtensionView;
@interface IFNewInform7ExtensionFile : NSObject<IFNewProjectProtocol>

@end

// (This class name sounds suspiciously likes a free sample from one of those spams...)
@interface IFNewInform7ExtensionView : NSObject<IFNewProjectSetupView>

- (void) setupControls;
@property (atomic, readonly, copy) NSString *authorName;
@property (atomic, readonly, copy) NSString *extensionName;
- (void) setInitialFocus: (NSWindow*) window;

@end
