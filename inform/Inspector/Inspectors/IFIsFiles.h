//
//  IFIsFiles.h
//  Inform
//
//  Created by Andrew Hunter on Mon May 31 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IFInspector.h"

extern NSString* IFIsFilesInspector;

@interface IFIsFiles : IFInspector

+ (IFIsFiles*) sharedIFIsFiles;							// The shared files inspector

- (IBAction) removeFile: (id) sender;					// Removes the currently selected file(s) from the project

- (void) updateFiles;									// Updates the list of files
- (void) setSelectedFile;								// Sets the currently selected file to the one being displayed in the source pane of the current window

@end
