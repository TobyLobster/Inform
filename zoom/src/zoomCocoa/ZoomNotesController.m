//
//  ZoomNotesController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/12/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "ZoomNotesController.h"


@implementation ZoomNotesController

// = The shared controller =

static NSMutableDictionary* notesDictionary = nil;

+ (ZoomNotesController*) sharedNotesController {
	static ZoomNotesController* sharedController = nil;

	if (sharedController == nil) {
		sharedController = [[ZoomNotesController alloc] init];
	}
	
	return sharedController;
}

- (id) init {
	NSString* path = [[NSBundle bundleForClass: [ZoomNotesController class]] pathForResource: @"NoteWindow"
																					  ofType: @"nib"];
	self = [self initWithWindowNibPath: path
								 owner: self];
	
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(applicationWillTerminate:)
													 name: NSApplicationWillTerminateNotification
												   object: nil];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[story release];
	[super dealloc];
}

// = Editing delegate =

- (void)textDidEndEditing:(NSNotification *)aNotification {
	ZoomStoryID* storyId = nil;
	
	if (story) storyId = [[story storyIDs] objectAtIndex: 0];
	
	if (storyId == nil) {
		// Nothing to do
	} else {
		// Update the notes for this story
		NSData* rtfNotes = [[notes textStorage] RTFFromRange: NSMakeRange(0, [[notes textStorage] length])
										  documentAttributes: nil];
		if (rtfNotes != nil) {
			[notesDictionary setObject: rtfNotes
								forKey: [storyId description]];
			[[NSUserDefaults standardUserDefaults] setObject: notesDictionary
													  forKey: @"ZoomNotes"];
		}
	}
}

- (void) applicationWillTerminate: (NSNotification*) not {
	if (story) [self textDidEndEditing: nil];
}

// = Setting up the window =

- (void) updateFromStory {
	NSAttributedString* currentNotes = nil;
	ZoomStoryID* storyId = nil;
	
	if (story) storyId = [[story storyIDs] objectAtIndex: 0];
	
	if (storyId == nil) {
		// No notes available
		[notes setEditable: NO];
		[notes setString: @"No notes available"];
	} else {
		// Should be some notes for this story
		if (notesDictionary == nil) {
			notesDictionary = [[[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomNotes"] mutableCopy];
			if (notesDictionary == nil) notesDictionary = [[NSMutableDictionary alloc] init];
		}
		NSData* rtfNotes = [notesDictionary objectForKey: [storyId description]];
		if (rtfNotes) {
			currentNotes = [[[NSAttributedString alloc] initWithRTF: rtfNotes
												 documentAttributes: nil] autorelease];
		}
		
		if (currentNotes == nil) {
			currentNotes = [[[NSAttributedString alloc] initWithString: @"" 
															attributes: [NSDictionary dictionaryWithObjectsAndKeys:
																[NSFont systemFontOfSize: 10], NSFontAttributeName,
																nil]] autorelease];
		}
		
		[[notes textStorage] setAttributedString: currentNotes];
		
		[notes setEditable: YES];
	}
}

- (void) windowDidLoad {
	[self setWindowFrameAutosaveName: @"ZoomNoteWindow"];
	
	[self updateFromStory];
}

- (void) setGameInfo: (ZoomStory*) newStory {
	[self textDidEndEditing: nil];
	
	[story release];
	story = [newStory retain];
	
	[self updateFromStory];
}

- (void) setInfoOwner: (id) newOwner {
	owner = newOwner;
}

- (id) infoOwner {
	return owner;
}

@end
