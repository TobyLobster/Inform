//
//  IFIsFiles.h
//  Inform
//
//  Created by Andrew Hunter on Mon May 31 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IFInspector.h"
#import "IFProject.h"
#import "IFProjectController.h"

extern NSString* IFIsFilesInspector;

@interface IFIsFiles : IFInspector {
	IBOutlet NSTableView* filesView;					// The table of files
	IBOutlet NSButton* addFileButton;					// Button to add new files
	IBOutlet NSButton* removeFileButton;				// Button to remove old files
	
	IFProject* activeProject;							// The currently active project
	IFProjectController* activeController;				// The currently active window controller (if a ProjectController)
	NSArray* filenames;									// The filename sin the current project
	NSWindow* activeWin;								// The currently active window
}

+ (IFIsFiles*) sharedIFIsFiles;							// The shared files inspector

- (IBAction) removeFile: (id) sender;					// Removes the currently selected file(s) from the project

- (void) updateFiles;									// Updates the list of files
- (void) setSelectedFile;								// Sets the currently selected file to the one being displayed in the source pane of the current window

@end
