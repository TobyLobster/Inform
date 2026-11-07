//
//  IFNewProject.h
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "IFProjectTypes.h"
#import "IFProject.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, IFNewProjectFlow) {
    IFNewProjectNone     = 0,
    IFNewProjectOptions  = 1,
    IFNewProjectLocation = 2,
};

///
/// Window controller for the 'new project' window
///
@interface IFNewProject : NSWindowController

-(IBAction) cancelButtonClicked: (nullable id) sender;
-(IBAction) okButtonClicked: (nullable id) sender;

- (void) createInform7ExtensionProject: (NSString*) title
                      fromExtensionURL: (NSURL*) extensionURL;
- (void) createInform7Project: (nullable NSString*) title
                     fileType: (IFFileType) fileType
                        story: (nullable NSString*) story;
- (void) createInform7ExtensionForProject: (IFProject*) project;

@end

NS_ASSUME_NONNULL_END
