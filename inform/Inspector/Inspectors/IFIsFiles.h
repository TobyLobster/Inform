//
//  IFIsFiles.h
//  Inform
//
//  Created by Andrew Hunter on Mon May 31 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IFInspector.h"

extern NSString* const IFIsFilesInspector;

@interface IFIsFiles : IFInspector <NSTableViewDataSource, NSTableViewDelegate>

/// The shared files inspector
+ (IFIsFiles*) sharedIFIsFiles;

/// Removes the currently selected file(s) from the project
- (IBAction) removeFile: (id) sender;

/// Updates the list of files
- (void) updateFiles;
/// Sets the currently selected file to the one being displayed in the source pane of the current window
- (void) setSelectedFile;

@end
