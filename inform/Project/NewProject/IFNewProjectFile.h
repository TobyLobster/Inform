//
//  IFNewProjectFile.h
//  Inform
//
//  Created by Andrew Hunter on Tue Jun 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class IFProjectController;

///
/// Window controller that handles the dialog that's presented when we want to add a new file to
/// a project
///
@interface IFNewProjectFile : NSWindowController

/// Initialises this object
- (instancetype) initWithProjectController: (IFProjectController*) control;

/// Cancels the action
- (IBAction) cancel: (nullable id) sender;
/// Performs the action
- (IBAction) addFile: (nullable id) sender;

/// Retrieves the name of the file that should be created (nil if the dialog was cancelled)
@property (atomic, getter=getNewFilename, readonly, copy, nullable) NSString *newFilename;

@end

NS_ASSUME_NONNULL_END
