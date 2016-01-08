//
//  IFNewProjectFile.h
//  Inform
//
//  Created by Andrew Hunter on Tue Jun 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

@class IFProjectController;

//
// Window controller that handles the dialog that's presented when we want to add a new file to
// a project
//
@interface IFNewProjectFile : NSWindowController

- (instancetype) initWithProjectController: (IFProjectController*) control;	// Initialises this object

- (IBAction) cancel: (id) sender;									// Cancels the action
- (IBAction) addFile: (id) sender;									// Performs the action

@property (atomic, getter=getNewFilename, readonly, copy) NSString *newFilename;    // Retrieves the name of the file that should be created

@end
