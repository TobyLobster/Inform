//
//  IFNewProject.h
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "IFProjectTypes.h"

@class IFProjectType;

typedef enum IFNewProjectFlow {
    IFNewProjectNone     = 0,
    IFNewProjectOptions  = 1,
    IFNewProjectLocation = 2,
} IFNewProjectFlow;

//
// Window controller for the 'new project' window
//
@interface IFNewProject : NSWindowController<NSOpenSavePanelDelegate>

-(IBAction) cancelButtonClicked: (id) sender;
-(IBAction) okButtonClicked: (id) sender;

- (void) createInform7ExtensionProject: (NSString*) title
                      fromExtensionURL: (NSURL*) extensionURL;
- (void) createInform7Project: (NSString*) title
                     fileType: (IFFileType) fileType
                        story: (NSString*) story;
- (void) createInform7Extension;
- (void) createInform6Project;

@end
