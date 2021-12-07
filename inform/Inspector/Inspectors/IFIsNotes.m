//
//  IFIsNotes.m
//  Inform
//
//  Created by Andrew Hunter on Fri May 07 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsNotes.h"
#import "IFProjectController.h"
#import "IFUtility.h"
#import "NSBundle+IFBundleExtensions.h"
#import "IFProject.h"

NSString* const IFIsNotesInspector = @"IFIsNotesInspector";

@implementation IFIsNotes {
    /// Currently selected project
    IFProject* activeProject;

    /// The text view that will contain the notes
    IBOutlet NSTextView* text;
}

+ (IFIsNotes*) sharedIFIsNotes {
	static IFIsNotes* notes = nil;
	
	if (!notes) {
		notes = [[IFIsNotes alloc] init];
	}
	
	return notes;
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		[NSBundle oldLoadNibNamed: @"NoteInspector"
                            owner: self];
		[self setTitle: [IFUtility localizedString: @"Inspector Notes"
                                           default: @"Notes"]];
		activeProject = nil;
	}
	
	return self;
}


- (void) inspectWindow: (NSWindow*) newWindow {
    activeProject = nil;

	// Set the notes layout manager to be us
	NSWindowController* control = [newWindow windowController];
	
	if (control != nil && [control isKindOfClass: [IFProjectController class]]) {
		activeProject = [control document];
		
        if( [activeProject notes] != nil ) {
            [text.layoutManager replaceTextStorage: [activeProject notes]];
        }
		[text setEditable: YES];
	} else {
		static NSTextStorage* noNotes = nil;
		
		if (!noNotes) noNotes = [[NSTextStorage alloc] initWithString: NSLocalizedString(@"No notes available", @"No notes available")];
		
        [text.layoutManager replaceTextStorage: noNotes];
		[text setEditable: NO];
	}
}

- (BOOL) available {
	return activeProject==nil?NO:YES;
}

- (NSString*) key {
	return IFIsNotesInspector;
}

@end
