//
//  IFNewProjectFile.m
//  Inform
//
//  Created by Andrew Hunter on Tue Jun 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFNewProjectFile.h"
#import "IFProject.h"
#import "IFCompilerSettings.h"
#import "IFProjectController.h"

NS_ENUM(NSInteger) {
	inform6FileTag = 0,
	niFileTag = 1,
	textFileTag = 2,
	richTextFileTag = 3
};

@implementation IFNewProjectFile {
    /// The project controller for the project that's getting a new file
    IFProjectController* projectController;

    /// Used to select the type of file
    IBOutlet NSPopUpButton* fileType;
    /// Used to enter the new file name
    IBOutlet NSTextField*   fileName;

    /// Stores the filename that the new file will have
    NSString* newFilename;
}

- (instancetype) initWithProjectController: (IFProjectController*) control {
	self = [super initWithWindowNibName: @"NewFile"];
	
	if (self) {
		projectController = control;
		newFilename = nil;
	}
	
	return self;
}


#pragma mark - Actions

@synthesize newFilename;
- (NSString*) getNewFilename {
    // Default is to create a 'ni' file
    [fileType selectItem: [fileType.menu itemWithTag: niFileTag]];

	// Set the new filename to nothing
	newFilename = nil;
	
	// Run the sheet
    [projectController.window beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
        // do nothing?
    }];
	[NSApp runModalForWindow: self.window];
	[NSApp endSheet: self.window];
	[self.window orderOut: self];
	
	return newFilename;
}

- (IBAction) cancel: (id) sender {
	// Am assuming we're a sheet. Which we should always be
	[NSApp stopModal];
}

- (IBAction) addFile: (id) sender {
	// Am assuming we're a sheet. Which we should always be
	[NSApp stopModal];

	// Work out the extension to use
	NSString* extension = nil;
	
	switch (fileType.selectedItem.tag) {
		case inform6FileTag:
            extension = @"i6";
			break;
		case niFileTag:
			if ([projectController.document editingExtension])
				extension = nil;
			else
				extension = @"ni";
			break;
		case textFileTag:
			extension = @"txt";
			break;
		case richTextFileTag:
			extension = @"rtf";
			break;
	}
	
	// ... now the whole filename
	NSString* file = fileName.stringValue.lastPathComponent;
	if (extension && file && file.length > 0) {
		newFilename = [file stringByAppendingPathExtension: extension];
	} else if (file && file.length > 0) {
		newFilename = [file copy];
	}
}

@end
