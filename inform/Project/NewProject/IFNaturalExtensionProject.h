//
//  IFNaturalExtensionProject.h
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFProjectType.h"

//
// Project type that makes it possible to create new Natural Inform extensions directories
//
@class IFNaturalExtensionView;
@interface IFNaturalExtensionProject : NSObject<IFProjectType> {
	IFNaturalExtensionView* vw;
}

@end

// (This class name sounds suspiciously likes a free sample from one of those spams...)
@interface IFNaturalExtensionView : NSObject<IFProjectSetupView> {
	IBOutlet NSView* view;
	
    IBOutlet NSTextField* name;
	IBOutlet NSTextField* extensionName;
}

- (void) setupControls;
- (NSString*) authorName;
- (NSString*) extensionName;
- (void) setInitialFocus: (NSWindow*) window;

@end
