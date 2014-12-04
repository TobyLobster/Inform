//
//  IFNewProject.h
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "IFProjectType.h"

@class IFProjectType;

typedef enum IFNewProjectFlow {
    IFNewProjectNone     = 0,
    IFNewProjectOptions  = 1,
    IFNewProjectLocation = 2,
} IFNewProjectFlow;

//
// Window controller for the 'new project' window
//
@interface IFNewProject : NSWindowController<NSOpenSavePanelDelegate> {
    IBOutlet NSView*                projectPaneView;	// The pane that contains the display for the current stage in the creation process
    IBOutlet NSTextField*           promptTextField;

    NSObject<IFProjectType>*        projectType;        // The current project type
    NSObject<IFProjectSetupView>*   projectView;        // The view of (Inform 6 project) settings
    NSArray*                        projectFileTypes;
    NSString*                       projectTitle;
    NSString*                       projectPrompt;
    NSString*                       projectStory;
    NSString*                       projectDefaultFilename;
    IFNewProjectFlow                projectFlow;

    NSURL*                          projectLocation;
}

-(IBAction) cancelButtonClicked: (id) sender;
-(IBAction) okButtonClicked: (id) sender;

- (void) createInform7Project: (NSString*) title
                        story: (NSString*) story;
- (void) createInform7Extension;
- (void) createInform6Project;

@end
