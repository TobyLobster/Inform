//
//  IFProjectType.h
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFProjectFile.h"


@protocol IFProjectSetupView;

//
// Objects implementing this protocol specify a type of project that can be created via the
// new project dialog.
//
@protocol IFProjectType

- (NSObject<IFProjectSetupView>*) configView;				// nil, or a project type-specific view that can be used to customise the new project. Should be reallocated every time this is called.

- (void) setupFile: (IFProjectFile*) file					// Request to setup a file from the given IFProjectSetupView (which will have been previously created by configView)
          fromView: (NSObject<IFProjectSetupView>*) view
         withStory: (NSString*) story;
-(void) setInitialFocus: (NSWindow*) window;
-(NSRange) initialSelectionRange;

@end

@protocol IFProjectSetupView

- (NSView*) view;											// The view that's displayed for this projects custom settings

@end

//
// Objects implementing the IFProjectType protocol may also implement these functions.
//
@interface NSObject(IFProjectTypeOptionalMethods)

- (NSString*) confirmationMessage;						// Return a string to display an 'are you sure' type message
- (NSString*) errorMessage;								// Return a string to indicate an error with the way things are set up
- (NSString*) saveFilename;								// If showFinalPage is NO, this is the filename to create
- (NSString*) openAsType;								// If present, the file type to open this project as
- (BOOL) createAndOpenDocument: (NSURL*) fileURL;       // If present, creates and opens the document associated with this view

@end
