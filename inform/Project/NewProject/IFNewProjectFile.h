//
//  IFNewProjectFile.h
//  Inform
//
//  Created by Andrew Hunter on Tue Jun 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

@class IFProjectController;

///
/// Window controller that handles the dialog that's presented when we want to add a new file to
/// a project
///
@interface IFNewProjectFile : NSWindowController

/// Initialises this object
- (instancetype) initWithProjectController: (IFProjectController*) control NS_DESIGNATED_INITIALIZER;

/// Cancels the action
- (IBAction) cancel: (id) sender;
/// Performs the action
- (IBAction) addFile: (id) sender;

/// Retrieves the name of the file that should be created
@property (atomic, getter=getNewFilename, readonly, copy) NSString *newFilename;

@end
