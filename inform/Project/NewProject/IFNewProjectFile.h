//
//  IFNewProjectFile.h
//  Inform
//
//  Created by Andrew Hunter on Tue Jun 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "IFProjectController.h"

//
// Window controller that handles the dialog that's presented when we want to add a new file to
// a project
//
@interface IFNewProjectFile : NSWindowController {
	IFProjectController* projectController;			// The project controller for the project that's getting a new file
	
	IBOutlet NSPopUpButton* fileType;				// Used to select the type of file
	IBOutlet NSTextField*   fileName;				// Used to enter the new file name
	
	NSString* newFilename;							// Stores the filename that the new file will have
}

- (id) initWithProjectController: (IFProjectController*) control;	// Initialises this object

- (IBAction) cancel: (id) sender;									// Cancels the action
- (IBAction) addFile: (id) sender;									// Performs the action

- (NSString*) getNewFilename;										// Retrieves the name of the file that should be created

@end
