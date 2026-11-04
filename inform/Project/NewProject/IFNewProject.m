//
//  IFNewProject.m
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//
// List of projects
// Inform 7 Project:        IFEmptyNaturalProject
// Inform 7 Extension:      IFNaturalExtensionProject

#import <Foundation/Foundation.h>
#import "IFNewProject.h"
#import "IFProjectFile.h"
#import "IFProject.h"

#import "IFNewInform7Project.h"
#import "IFNewInform7ExtensionProject.h"
#import "IFNewInform7ExtensionFile.h"
#import "IFUtility.h"

@implementation IFNewProject {
    IBOutlet NSView*                    projectPaneView;	// The pane that contains the display for the current stage in the creation process
    IBOutlet NSTextField*               promptTextField;

    id<IFNewProjectProtocol>            projectType;        // The current project type
    id<IFNewProjectSetupView>           projectView;        // The view of (Inform 6 project) settings
    NSArray*                            projectFileTypes;
    NSString*                           projectTitle;
    NSString*                           projectPrompt;
    NSString*                           projectStory;
    NSURL*                              projectExtensionURL;
    NSString*                           projectDefaultFilename;
    IFNewProjectFlow                    projectFlow;
    __weak IFProject*                   project;

    NSURL*                              projectLocation;    // Location of extension file or extension project
}

#pragma mark - Initialisation

+ (void) initialize {
}

- (instancetype) init {
    self = [super initWithWindowNibName: @"NewProject"];

    if (self) {
    }

    return self;
}


#pragma mark - Interface

-(BOOL) isExtension {
    return [projectType isKindOfClass:[IFNewInform7ExtensionFile class]];
}

- (void) createExtension {
    IFNewInform7ExtensionFile* proj = (IFNewInform7ExtensionFile*) projectType;

    projectLocation = [NSURL fileURLWithPath: proj.saveFilename];
    if ([proj createAndOpenDocument: projectLocation]) {
        // Success
        return;
    } else {
        [IFUtility runAlertWarningWindow: self.window
                                   title: @"Unable to create project"
                                 message: @"Inform was unable to save the extension file"];
    }
}

- (void) createProject {
	IFProjectFile* theFile = [[IFProjectFile alloc] initWithEmptyProject];
	BOOL success;

	theFile.filename = projectLocation.path;
	[projectType setupFile: theFile
				  fromView: projectView
                 withStory: projectStory
          withExtensionURL: projectExtensionURL];

	success = theFile.write;

	if (success) {
        NSError* error;
        // Create IFProject (an NSDocument)
		IFProject* newDoc = [[IFProject alloc] initWithContentsOfURL: projectLocation
                                                              ofType: projectType.typeName
                                                               error: &error];
        newDoc.initialSelectionRange = projectType.initialSelectionRange;
        [newDoc createMaterials];

		[[NSDocumentController sharedDocumentController] addDocument: newDoc];
		[newDoc makeWindowControllers];
		[newDoc showWindows];
	} else {
        [IFUtility runAlertWarningWindow: self.window
                                   title: @"Unable to create project"
                                 message: @"Inform was unable to save the project file"];
	}
}

-(void) createItem {
    // Create extension
    if( [self isExtension] ) {
        [self createExtension];
        return;
    }

    // Create project
    [self createProject];
}

-(void) close {
    projectTitle            = nil;
    projectPrompt           = nil;
    projectFileTypes        = nil;
    projectStory            = nil;
    projectDefaultFilename  = nil;
    [projectView.view removeFromSuperview];
    projectView             = nil;
    projectLocation         = nil;
    projectType             = nil;

    [self.window close];
}

- (NSWindow*) visibleWindow {
    if( self.window.visible ) {
        return self.window;
    }
    return nil;
}

- (BOOL) validate {
    NSWindow* win = [self visibleWindow];

    if( [projectType respondsToSelector: @selector(errorMessage)]) {
        NSString* error = projectType.errorMessage;

        if( error != nil ) {
            [IFUtility runAlertWarningWindow: win
                                       title: @"Error"
                                     message: @"%@", error];
            return NO;
        }
    }

    if( [projectType respondsToSelector: @selector(confirmationMessage)]) {
        NSString* confirm = projectType.confirmationMessage;
        
        if( confirm != nil ) {
            [IFUtility runAlertYesNoWindow: win
                                     title: [IFUtility localizedString: @"Are you sure?"]
                                       yes: [IFUtility localizedString: @"Create"]
                                        no: [IFUtility localizedString: @"Cancel"]
                             modalDelegate: self
                            didEndSelector: @selector(confirmDidEnd:returnCode:contextInfo:)
                               contextInfo: nil
                                   message: @"%@", confirm];
            return NO;
        }
    }

    [self createItem];
    [self close];
    return YES;
}

- (void) confirmDidEnd:(NSWindow *)sheet returnCode:(NSModalResponse)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSAlertFirstButtonReturn) {
		[self createItem];
        [self close];
	}
}

- (void) chooseLocation {
    // Setup a save panel
    NSSavePanel* panel = [NSSavePanel savePanel];

    [panel setAccessoryView: nil];
    panel.allowedFileTypes = projectFileTypes;
    panel.delegate = self;
    panel.prompt = projectPrompt;
    [panel setTreatsFilePackagesAsDirectories: NO];
    if( projectDefaultFilename != nil ) {
        panel.nameFieldStringValue = projectDefaultFilename;
    }

    //NSArray* urls = [[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory
    //                                                       inDomains: NSUserDomainMask];
    //[panel setDirectoryURL:[urls objectAtIndex:0]];

    // Use any currently visible window
    NSWindow* win = nil;
    if( self.window.visible ) {
        win = self.window;
    }

    // Show it
    [panel beginSheetModalForWindow: win
                  completionHandler: ^(NSInteger result)
     {
         if (result == NSModalResponseOK) {
             self->projectLocation = panel.URL;

             [self validate];
         }
         
         // Finished
         [self close];
     }];
}

-(IBAction) cancelButtonClicked: (id) sender {
    [self close];
}

-(IBAction) okButtonClicked: (id) sender {
    if (projectFlow & IFNewProjectLocation ) {
        [self chooseLocation];
    } else {
        if( [self validate] ) {
            [self close];
        }
    }
}

-(void) chooseOptions {
    [self showWindow: self];
    self.window.title = projectTitle;
    promptTextField.stringValue = projectPrompt;
    
    projectView.view.frame = projectPaneView.bounds;

    [projectPaneView addSubview: projectView.view
                     positioned: NSWindowAbove
                     relativeTo: nil ];

    [projectType setInitialFocus: self.window];
}

-(void) startFlow {
    if( projectFlow & IFNewProjectOptions ) {
        [self chooseOptions];
    } else if (projectFlow & IFNewProjectLocation ) {
        [self chooseLocation];
    } else {
        [self validate];
    }
}

- (void) createInform7ExtensionProject: (NSString*) title
                      fromExtensionURL: (NSURL*) extensionURL {
    [self close];

    projectType             = [[IFNewInform7ExtensionProject alloc] init];
    projectFileTypes        = @[@"i7xp"];
    projectTitle            = [IFUtility localizedString: @"Create Extension Project"];
    projectPrompt           = [IFUtility localizedString: @"Create Extension Project"];
    projectView             = projectType.configView;
    projectFlow             = IFNewProjectLocation;
    projectStory            = nil;
    projectExtensionURL     = extensionURL;
    projectDefaultFilename  = title;

    [self startFlow];
}


- (void) createInform7Project: (NSString*) title
                     fileType: (IFFileType) fileType
                        story: (NSString*) story {
    [self close];

    if( fileType == IFFileTypeInform7Project )
    {
        projectType         = [[IFNewInform7Project alloc] init];
        projectFileTypes    = @[@"inform"];
    }
    else if( fileType == IFFileTypeInform7ExtensionProject )
    {
        projectType         = [[IFNewInform7ExtensionProject alloc] init];
        projectFileTypes    = @[@"i7xp"];
    }
    else
    {
        NSAssert(false, @"invalid project type");
        return;
    }
    projectTitle        = [IFUtility localizedString: @"Create Project"];
    projectPrompt       = [IFUtility localizedString: @"Create Project"];
    projectView         = projectType.configView;
    projectFlow         = IFNewProjectLocation;
    projectStory        = story;
    projectExtensionURL     = nil;
    projectDefaultFilename  = title;

    [self startFlow];
}

- (void) createInform7ExtensionForProject: (IFProject*) theProject {
    [self close];

    projectType      = [[IFNewInform7ExtensionFile alloc] initWithProject: theProject];
    projectFileTypes = @[@"i7x"];
    projectTitle     = [IFUtility localizedString: @"Create Extension"];
    projectPrompt    = [IFUtility localizedString: @"Create Extension"];
    projectView      = projectType.configView;
    projectFlow      = IFNewProjectOptions;
    projectStory     = nil;
    projectExtensionURL    = nil;
    projectDefaultFilename = nil;
    project          = theProject;

    [self startFlow];
}

@end
