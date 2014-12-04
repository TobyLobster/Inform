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

NSString* IFIsNotesInspector = @"IFIsNotesInspector";

@implementation IFIsNotes

+ (IFIsNotes*) sharedIFIsNotes {
	static IFIsNotes* notes = nil;
	
	if (!notes) {
		notes = [[IFIsNotes alloc] init];
	}
	
	return notes;
}

- (id) init {
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

- (void) dealloc {
	if (activeProject) [activeProject release];
	[super dealloc];
}

- (void) inspectWindow: (NSWindow*) newWindow {
    [activeProject release];
    activeProject = nil;

	// Set the notes layout manager to be us
	NSWindowController* control = [newWindow windowController];
	
	if (control != nil && [control isKindOfClass: [IFProjectController class]]) {
		activeProject = [[control document] retain];
		
        if( [activeProject notes] != nil ) {
            [text.layoutManager replaceTextStorage: [activeProject notes]];
        }
		[text setEditable: YES];
	} else {
		static NSTextStorage* noNotes = nil;
		
		if (!noNotes) noNotes = [[NSTextStorage alloc] initWithString: @"No notes available"];
		
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
