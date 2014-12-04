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
// Inform 6 Project(empty): IFEmptyProject
// Inform 6 Project:        IFStandardProject

#import "IFNewProject.h"
#import "IFProjectFile.h"
#import "IFProject.h"

#import "IFEmptyProject.h"
#import "IFStandardProject.h"
#import "IFEmptyNaturalProject.h"
#import "IFNaturalExtensionProject.h"
#import "IFUtility.h"

@implementation IFNewProject

// = Initialisation =

+ (void) initialize {
}

- (id) init {
    self = [super initWithWindowNibName: @"NewProject"];

    if (self) {
    }

    return self;
}

- (void) dealloc {
    [super dealloc];
}

// = Interface =

-(BOOL) isExtension {
    return [projectType isKindOfClass:[IFNaturalExtensionProject class]];
}

- (void) createExtension {
    IFNaturalExtensionProject* proj = (IFNaturalExtensionProject*) projectType;

    projectLocation = [NSURL fileURLWithPath: [proj saveFilename]];
    if ([proj createAndOpenDocument: projectLocation]) {
        // Success
        return;
    } else {
        [IFUtility runAlertWarningWindow: [self window]
                                   title: @"Unable to create project"
                                 message: @"Inform was unable to save the project file"];
    }
}

- (void) createProject {
	IFProjectFile* theFile = [[IFProjectFile alloc] initWithEmptyProject];
	BOOL success;

	[theFile setFilename: [projectLocation path]];
	[projectType setupFile: theFile
				  fromView: projectView
                 withStory: projectStory];

	success = [theFile write];
    [theFile release];

	if (success) {
        NSError* error;
		IFProject* newDoc = [[IFProject alloc] initWithContentsOfURL: projectLocation
                                                              ofType: @"Inform project"
                                                               error: &error];
        [newDoc setInitialSelectionRange: [projectType initialSelectionRange]];
		[[NSDocumentController sharedDocumentController] addDocument: [newDoc autorelease]];
		[newDoc makeWindowControllers];
		[newDoc showWindows];
	} else {
        [IFUtility runAlertWarningWindow: [self window]
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
    [projectTitle release];
    projectTitle = nil;
    [projectPrompt release];
    projectPrompt = nil;
    [projectFileTypes release];
    projectFileTypes = nil;
    [projectStory release];
    projectStory = nil;
    [projectDefaultFilename release];
    projectDefaultFilename = nil;

    [[projectView view] removeFromSuperview];
    [projectView release];
    projectView = nil;
    projectLocation = nil;
    projectType = nil;

    [[self window] close];
}

- (NSWindow*) visibleWindow {
    if( [[self window] isVisible] ) {
        return [self window];
    }
    return nil;
}

- (BOOL) validate {
    NSWindow* win = [self visibleWindow];

    if( [projectType respondsToSelector: @selector(errorMessage)]) {
        NSString* error = [projectType errorMessage];

        if( error != nil ) {
            [IFUtility runAlertWarningWindow: win
                                       title: @"Error"
                                     message: @"%@", error];
            return NO;
        }
    }

    if( [projectType respondsToSelector: @selector(confirmationMessage)]) {
        NSString* confirm = [projectType confirmationMessage];
        
        if( confirm != nil ) {
            [IFUtility runAlertYesNoWindow: win
                                     title: [IFUtility localizedString: @"Are you sure?"]
                                       yes: [IFUtility localizedString: @"Create"]
                                        no: [IFUtility localizedString: @"Cancel"]
                             modalDelegate: self
                            didEndSelector: @selector(confirmDidEnd:returnCode:contextInfo:)
                               contextInfo: nil
                                   message: confirm];
            return NO;
        }
    }

    [self createItem];
    [self close];
    return YES;
}

- (void) confirmDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSAlertFirstButtonReturn) {
		[self createItem];
        [self close];
	}
}

- (void) chooseLocation {
    // Setup a save panel
    NSSavePanel* panel = [NSSavePanel savePanel];

    [panel setAccessoryView: nil];
    [panel setAllowedFileTypes: projectFileTypes];
    [panel setDelegate: self];
    [panel setPrompt: projectPrompt];
    [panel setTreatsFilePackagesAsDirectories: NO];
    if( projectDefaultFilename != nil ) {
        [panel setNameFieldStringValue: projectDefaultFilename];
    }

    //NSArray* urls = [[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory
    //                                                       inDomains: NSUserDomainMask];
    //[panel setDirectoryURL:[urls objectAtIndex:0]];

    // Use any currently visible window
    NSWindow* win = nil;
    if( [[self window] isVisible] ) {
        win = [self window];
    }

    // Show it
    [panel beginSheetModalForWindow: win
                  completionHandler: ^(NSInteger result)
     {
         if (result == NSOKButton) {
             projectLocation = [panel URL];

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
    [[self window] setTitle: projectTitle];
    [promptTextField setStringValue: projectPrompt];
    
    [[projectView view] setFrame: [projectPaneView bounds]];

    [projectPaneView addSubview: [projectView view]
                     positioned: NSWindowAbove
                     relativeTo: nil ];

    [projectType setInitialFocus: [self window]];
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

- (void) createInform7Project: (NSString*) title
                        story: (NSString*) story {
    [self close];

    projectType         = [[IFEmptyNaturalProject alloc] init];
    projectFileTypes    = [[NSArray arrayWithObject:@"inform"] retain];
    projectTitle        = [[IFUtility localizedString: @"Create Project"] retain];
    projectPrompt       = [[IFUtility localizedString: @"Create Project"] retain];
    projectView         = [[projectType configView] retain];
    projectFlow         = IFNewProjectLocation;
    projectStory        = [story retain];
    projectDefaultFilename  = [title retain];

    [self startFlow];
}

- (void) createInform7Extension {
    [self close];

    projectType      = [[IFNaturalExtensionProject alloc] init];
    projectFileTypes = [[NSArray arrayWithObject:@"i7x"] retain];
    projectTitle     = [[IFUtility localizedString: @"Create Extension"] retain];
    projectPrompt    = [[IFUtility localizedString: @"Create Extension"] retain];
    projectView      = [[projectType configView] retain];
    projectFlow      = IFNewProjectOptions;
    projectStory     = nil;
    projectDefaultFilename = nil;

    [self startFlow];
}

- (void) createInform6Project {
    [self close];

    projectType      = [[IFStandardProject alloc] init];
    projectFileTypes = [[NSArray arrayWithObject:@"inform"] retain];
    projectTitle     = [[IFUtility localizedString: @"Create Project"] retain];
    projectPrompt    = [[IFUtility localizedString: @"Create Project"] retain];
    projectView      = [[projectType configView] retain];
    projectFlow      = (IFNewProjectFlow) (IFNewProjectOptions | IFNewProjectLocation);
    projectStory     = nil;
    projectDefaultFilename = nil;

    [self startFlow];
}

@end
