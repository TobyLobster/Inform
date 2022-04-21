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

NSString* const IFIsFilesInspector = @"IFIsFilesInspector";

@implementation IFIsFiles {
    /// The table of files
    IBOutlet NSTableView* filesView;
    /// Button to add new files
    IBOutlet NSButton* addFileButton;
    /// Button to remove old files
    IBOutlet NSButton* removeFileButton;

    /// The currently active project
    IFProject* activeProject;
    /// The currently active window controller (if a ProjectController)
    IFProjectController* activeController;
    /// The filename sin the current project
    NSArray* filenames;
    /// The currently active window
    NSWindow* activeWin;
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

#pragma mark - Inspecting things

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
	
    // Not available for Natural Inform projects with only one file
    if ([[activeProject sourceFiles] count] == 1) return NO;

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


#pragma mark - Actions

- (IBAction) addNewFile: (id) sender {
	// Pass this to the active window
	if (activeWin != nil) {
		IFProjectController* contr = [activeWin windowController];
		if ([contr isKindOfClass: [IFProjectController class]])
			[contr addNewFile: self];
	}
}

- (IBAction) removeFile: (id) sender {
	if (activeWin == nil) return;
	if ([filenames count] <= 0) return;
	if ([filesView selectedRow] < 0) return;
	
	NSString* fileToRemove = filenames[[filesView selectedRow]];
	if (fileToRemove == nil) return;
	
	NSDictionary* status = @{@"fileToRemove": fileToRemove, @"windowController": [activeWin windowController]};

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [IFUtility localizedString: @"FileRemove - Are you sure"
                                           default: @"Are you sure you want to remove this file?"];
    alert.informativeText = [NSString stringWithFormat:[IFUtility localizedString: @"FileRemove - description"
                                                                          default: @"Are you sure you wish to permanently remove the file '%@' from the project? This action cannot be undone"], fileToRemove];
    [alert addButtonWithTitle:[IFUtility localizedString: @"FileRemove - keep file"
                                                 default: @"Keep it"]];
    NSButton *des = [alert addButtonWithTitle:[IFUtility localizedString: @"FileRemove - delete file"
                                                                 default: @"Delete it"]];
    if (@available(macOS 11, *)) {
        des.hasDestructiveAction = YES;
    }
    [alert beginSheetModalForWindow:activeWin completionHandler:^(NSModalResponse returnCode) {
        // Verify that we're all set up to delete the file
        if (self->activeWin == nil) {
            return;
        }
        if (status == nil) {
            return;
        }
        
        NSString* filename = status[@"fileToRemove"];
        IFProjectController* controller = status[@"windowController"];
        
        if (filename == nil || controller == nil)
        {
            return;
        }
        
        if (![controller isKindOfClass: [IFProjectController class]]) {
            return;
        }

        if (returnCode == NSAlertSecondButtonReturn) {
            // Delete this file
            [(IFProject*)[controller document] removeFile: filename];
        }
    }];
}

#pragma mark - Our life as a data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	if (activeProject == nil) return 0;
	
	NSUInteger fileRow = [filenames indexOfObject: [[activeController selectedSourceFile] lastPathComponent]];
	
	if (fileRow == NSNotFound)
		return [filenames count] + 1;
	else
		return [filenames count];
}

- (id)				tableView:(NSTableView *)aTableView 
	objectValueForTableColumn:(NSTableColumn *)aTableColumn 
						  row:(NSInteger)rowIndex {
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
		fileColour = [NSColor systemRedColor];
	}
	
	if ([[aTableColumn identifier] isEqualToString: @"filename"]) {
		if (fileColour == nil) fileColour = [NSColor textColor];
		
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
		CGFloat smallestSize = 128;
		
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
			  row:(NSInteger)rowIndex {
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

#pragma mark - Delegation is the key to success, apparently

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
