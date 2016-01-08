//
//  IFIsFiles.m
//  Inform
//
//  Created by Andrew Hunter on Mon May 31 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsFiles.h"
#import "IFProjectController.h"
#import "IFUtility.h"
#import "NSBundle+IFBundleExtensions.h"
#import "IFProject.h"
#import "IFCompilerSettings.h"

NSString* IFIsFilesInspector = @"IFIsFilesInspector";

@implementation IFIsFiles {
    IBOutlet NSTableView* filesView;					// The table of files
    IBOutlet NSButton* addFileButton;					// Button to add new files
    IBOutlet NSButton* removeFileButton;				// Button to remove old files

    IFProject* activeProject;							// The currently active project
    IFProjectController* activeController;				// The currently active window controller (if a ProjectController)
    NSArray* filenames;									// The filename sin the current project
    NSWindow* activeWin;								// The currently active window
}

+ (IFIsFiles*) sharedIFIsFiles {
	static IFIsFiles* files = nil;
	
	if (!files) {
		files = [[IFIsFiles alloc] init];
	}
	
	return files;
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		[NSBundle oldLoadNibNamed: @"FileInspector"
                            owner: self];
		[self setTitle: [IFUtility localizedString: @"Inspector Files"
                                           default: @"Files"]];
		activeProject = nil;
		activeController = nil;
		filenames = nil;
		
		// Set the icon column to NSImageCell
		[[filesView tableColumns][[filesView columnWithIdentifier: @"icon"]] setDataCell: 
			[[NSImageCell alloc] init]];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(updateFiles)
													 name: IFProjectFilesChangedNotification
												   object: nil];
	}
	
	return self;
}

- (void) dealloc {
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
}

// = Inspecting things =

static NSInteger stringComparer(id a, id b, void * context) {
	NSInteger cmp = [[(NSString*)a pathExtension] compare: [(NSString*)b pathExtension]];
	
	if (cmp == 0) return [(NSString*)a compare: (NSString*) b];
	return cmp;
}

- (void) inspectWindow: (NSWindow*) newWindow {
	activeWin = newWindow;
	
	activeProject = nil;
	activeController = nil;
	
	// Get the active project, if applicable
	NSWindowController* control = [newWindow windowController];
	
	if (control != nil && [control isKindOfClass: [IFProjectController class]]) {
		activeController = (IFProjectController*)control;
		activeProject = [control document];
	}
	
	[self updateFiles];
}

- (void) updateFiles {
	if (filenames) {
		filenames = nil;
	}
	
	if (!activeProject) return;
	
	filenames = [[[activeProject sourceFiles] allKeys] sortedArrayUsingFunction: stringComparer
																		context: nil];

	[filesView reloadData];
	
	[self setSelectedFile];
}

- (BOOL) available {
	// Not available if there's no project selected
	if (activeProject == nil) return NO;
	
	// Not available for Natural Inform projects with only one files
	if ([[activeProject settings] usingNaturalInform] &&
		[[activeProject sourceFiles] count] == 1) return NO;
	
	return YES;
}

- (NSString*) key {
	return IFIsFilesInspector;
}

- (void) setSelectedFile {
	if (activeController && [activeController isKindOfClass: [IFProjectController class]]) {
		NSUInteger fileRow = [filenames indexOfObject: [[activeController selectedSourceFile] lastPathComponent]];
		
		if (fileRow != NSNotFound) {
			[filesView selectRowIndexes:[NSIndexSet indexSetWithIndex:fileRow]
                   byExtendingSelection: NO];
		} else {
			[filesView deselectAll: self];
		}
	}
}


// = Actions =
- (IBAction) addNewFile: (id) sender {
	// Pass this to the active window
	if (activeWin != nil) {
		IFProjectController* contr = [activeWin windowController];
		if ([contr isKindOfClass: [IFProjectController class]])
			[contr addNewFile: self];
	}
}

// Ignore the casting of constness in "(void*)CFBridgingRetain(status)"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-qual"

- (IBAction) removeFile: (id) sender {
	if (activeWin == nil) return;
	if ([filenames count] <= 0) return;
	if ([filesView selectedRow] < 0) return;
	
	NSString* fileToRemove = filenames[[filesView selectedRow]];
	if (fileToRemove == nil) return;
	
	NSDictionary* status = @{@"fileToRemove": fileToRemove, @"windowController": [activeWin windowController]};

	NSBeginAlertSheet([IFUtility localizedString: @"FileRemove - Are you sure"
                                         default: @"Are you sure you want to remove this file?"],
					  [IFUtility localizedString: @"FileRemove - keep file"
                                         default: @"Keep it"],
                      [IFUtility localizedString: @"FileRemove - delete file"
                                         default: @"Delete it"],
					  nil, activeWin,
					  self, 
					  @selector(deleteFileFinished:returnCode:contextInfo:), nil, 
					  (void*)CFBridgingRetain(status),
					  [IFUtility localizedString: @"FileRemove - description"
                                         default: @"Are you sure you wish to permanently remove the file '%@' from the project? This action cannot be undone"],
					  fileToRemove);
}

#pragma clang diagnostic pop

- (void) deleteFileFinished: (NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSDictionary* fileInfo = CFBridgingRelease(contextInfo);

	// Verify that we're all set up to delete the file
    if (activeWin == nil) {
        return;
    }
    if (fileInfo == nil) {
        return;
    }
	
	NSString* filename = fileInfo[@"fileToRemove"];
	IFProjectController* controller = fileInfo[@"windowController"];
	
	if (filename == nil || controller == nil)
    {
        return;
    }
	
	if (![controller isKindOfClass: [IFProjectController class]]) {
		return;
	}

	if (returnCode == NSAlertAlternateReturn) {
		// Delete this file
		[(IFProject*)[controller document] removeFile: filename];
	}
}

// = Our life as a data source =

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	if (activeProject == nil) return 0;
	
	NSUInteger fileRow = [filenames indexOfObject: [[activeController selectedSourceFile] lastPathComponent]];
	
	if (fileRow == NSNotFound)
		return (int) [filenames count] + 1;
	else
		return (int) [filenames count];
}

- (id)				tableView:(NSTableView *)aTableView 
	objectValueForTableColumn:(NSTableColumn *)aTableColumn 
						  row:(int)rowIndex {
	NSString* path;
	NSString* fullPath;
	NSColor* fileColour = nil;
	
	if (rowIndex >= [filenames count]) {
		fullPath = [activeController selectedSourceFile];
		path = [fullPath lastPathComponent];
		
		fileColour = [NSColor blueColor];
	} else {
		path = filenames[rowIndex];
		fullPath = [activeProject pathForSourceFile: path];
	}
	
	if (path == nil) return nil;
	if (fullPath == nil) return nil;
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: fullPath]) {
		fileColour = [NSColor redColor];
	}
	
	if ([[aTableColumn identifier] isEqualToString: @"filename"]) {
		if (fileColour == nil) fileColour = [NSColor blackColor];
		
		NSString* filenameToUse = [path stringByDeletingPathExtension];
		
		return [[NSAttributedString alloc] initWithString: filenameToUse
												attributes: @{NSForegroundColorAttributeName: fileColour}];
	} else if ([[aTableColumn identifier] isEqualToString: @"icon"]) {
		NSImage* icon;
		
		// Use the icon for the file extension if the path doesn't exist
		if ([[NSFileManager defaultManager] fileExistsAtPath: fullPath]) {
			icon = [[NSWorkspace sharedWorkspace] iconForFile: fullPath];
		} else {
			icon = [[NSWorkspace sharedWorkspace] iconForFileType: [fullPath pathExtension]];
		}
		
		// Pick the smallest representation of the icon
		NSArray* reps = [icon representations];
		NSImageRep* repToUse;
		float smallestSize = 128;
		
		repToUse = nil;

		for( NSImageRep* thisRep in reps ) {
			NSSize repSize = [thisRep size];
			
			if (repSize.width < smallestSize) {
				repToUse = thisRep;
				smallestSize = repSize.width;
			}
		}
		
		if (repToUse != nil) {
			NSImage* newImg = [[NSImage alloc] init];
			[newImg addRepresentation: repToUse];
			return newImg;
		} else {
			return icon;
		}
	} else {
		return nil;
	}
}

- (void)tableView:(NSTableView *)aTableView 
   setObjectValue:(id)anObject 
   forTableColumn:(NSTableColumn *)aTableColumn 
			  row:(int)rowIndex {
	NSString* oldFile = filenames[rowIndex];
	if (![[aTableColumn identifier] isEqualToString: @"filename"]) return;
	if (oldFile == nil) return;
		
	if (![anObject isKindOfClass: [NSString class]]) return;
	if ([(NSString*)anObject length] <= 0) return;
	if ([[(NSString*)anObject pathComponents] count] != 1) return;
	
	if ([activeController isKindOfClass: [IFProjectController class]]) {
		IFProject* proj = [activeController document];
		NSString* newName = (NSString*)anObject;
		
		if ([oldFile pathExtension] &&
			![[oldFile pathExtension] isEqualToString: @""]) {
			newName = [newName stringByAppendingPathExtension: [oldFile pathExtension]];
		}
		
		[proj renameFile: oldFile
			 withNewName: newName];
		
		[aTableView reloadData];
		
		NSUInteger newIndex = [filenames indexOfObjectIdenticalTo: newName];
		if (newIndex != NSNotFound) {
			[aTableView selectRowIndexes: [NSIndexSet indexSetWithIndex:newIndex]
                    byExtendingSelection: NO];
			[self setSelectedFile];
		}
	}
}

// = Delegation is the key to success, apparently =

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	NSString* filename = nil;
	
	if ([filesView selectedRow] >= 0)
		filename = filenames[[filesView selectedRow]];
	
	if (filename) {
		if ([activeController isKindOfClass: [IFProjectController class]]) {
			[activeController selectSourceFile: filename];
		}
	}
}

@end
